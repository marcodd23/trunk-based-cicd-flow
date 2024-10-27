package config

import "github.com/marcodd23/go-micro-core/pkg/configx"

// ServiceConfig - service configuration that embed the base config from opoa-nexus-core-go
type ServiceConfig struct {
	configx.BaseConfig `mapstructure:",squash"`
}
