package database

import (
	"strings"

	"gorm.io/driver/postgres"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Initialize creates and initializes database connection
func Initialize(dsn string) (*gorm.DB, error) {
	var db *gorm.DB
	var err error

	// Use SQLite if dsn starts with "sqlite:"
	if strings.HasPrefix(dsn, "sqlite:") {
		db, err = gorm.Open(sqlite.Open(strings.TrimPrefix(dsn, "sqlite:")), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Info),
		})
	} else {
		db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Info),
		})
	}

	if err != nil {
		return nil, err
	}

	// Get underlying SQL DB for connection pooling
	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}

	// Set connection pool settings
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(100)

	return db, nil
}

// Migrate runs database migrations.
// For Postgres: ensures pgvector extension exists; drops the legacy bytea
// `embedding` column if present so AutoMigrate can recreate it as halfvec(3072);
// then builds an HNSW cosine index for ANN search.
func Migrate(db *gorm.DB, models ...interface{}) error {
	if db.Dialector.Name() == "postgres" {
		if err := db.Exec("CREATE EXTENSION IF NOT EXISTS vector").Error; err != nil {
			return err
		}
		// Drop legacy bytea embedding column (old schema stored raw float32 bytes);
		// AutoMigrate won't alter column types, so we drop + let it recreate as halfvec.
		var legacy bool
		db.Raw(`SELECT EXISTS (
			SELECT 1 FROM information_schema.columns
			WHERE table_name='ai_chat_messages'
			  AND column_name='embedding'
			  AND udt_name='bytea'
		)`).Scan(&legacy)
		if legacy {
			if err := db.Exec("ALTER TABLE ai_chat_messages DROP COLUMN embedding").Error; err != nil {
				return err
			}
		}

		// user_accounts.phone was NOT NULL in the SMS-only era. Google sign-in
		// introduces accounts with no phone — drop the NOT NULL so the pointer
		// field in models.UserAccount can write NULL. AutoMigrate won't relax
		// constraints on its own.
		var phoneNotNull bool
		db.Raw(`SELECT EXISTS (
			SELECT 1 FROM information_schema.columns
			WHERE table_name='user_accounts'
			  AND column_name='phone'
			  AND is_nullable='NO'
		)`).Scan(&phoneNotNull)
		if phoneNotNull {
			if err := db.Exec("ALTER TABLE user_accounts ALTER COLUMN phone DROP NOT NULL").Error; err != nil {
				return err
			}
		}
	}

	if err := db.AutoMigrate(models...); err != nil {
		return err
	}

	if db.Dialector.Name() == "postgres" {
		// HNSW cosine index on halfvec(3072) — pgvector 0.7+ supports halfvec up to 4000 dims.
		if err := db.Exec(`CREATE INDEX IF NOT EXISTS ai_chat_messages_embedding_hnsw
			ON ai_chat_messages USING hnsw (embedding halfvec_cosine_ops)`).Error; err != nil {
			return err
		}
	}
	return nil
}
