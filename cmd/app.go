package main

import (
	"context"
	"github.com/gofiber/fiber/v2"
	"github.com/marcodd23/trunk-based-cicd-flow/internal/config"
	"log"

	"github.com/marcodd23/go-micro-core/pkg/configx"
	"github.com/marcodd23/go-micro-core/pkg/logx"
	"github.com/marcodd23/go-micro-core/pkg/serverx/fibersrv"
	"github.com/marcodd23/go-micro-core/pkg/shutdown"
)

// ShutdownTimeoutMilli - timeout for cleaning up resources before shutting down the server.
const ShutdownTimeoutMilli = 500

func main() {
	rootCtx := context.Background()

	config := loadConfiguration()

	logx.SetupLogger(config)

	serverManager := fibersrv.NewFiberServer(config)

	// Setup Routes.
	serverManager.Setup(rootCtx, func(appServer *fiber.App) {
		appServer.Group("/v1/api")
		appServer.Get("/", func(c *fiber.Ctx) error {
			logx.GetLogger().LogInfo(c.Context(), "received GET request")

			return c.SendString("Hello, World!")
		})
	})

	// Start server
	serverManager.RunAsync()

	shutdown.WaitForShutdown(rootCtx, ShutdownTimeoutMilli, func(timeoutCtx context.Context) {
		serverManager.Shutdown(timeoutCtx)
	})
}

// loadConfiguration - loads config.
func loadConfiguration() *config.ServiceConfig {
	var cfg config.ServiceConfig

	err := configx.LoadConfigForEnv(&cfg)
	if err != nil {
		log.Panicf("error loading property files: %+v", err)
	}

	return &cfg
}
