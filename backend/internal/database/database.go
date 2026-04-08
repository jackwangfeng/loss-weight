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

// Migrate runs database migrations
func Migrate(db *gorm.DB, models ...interface{}) error {
	return db.AutoMigrate(models...)
}
