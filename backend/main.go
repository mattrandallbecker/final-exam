package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	v1 "weathercontrol/pkg/api"
	"weathercontrol/pkg/api/v1connect"

	connect "connectrpc.com/connect"
	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"

	connectcors "connectrpc.com/cors"
	_ "github.com/lib/pq"
	"github.com/rs/cors"
)

const address = "0.0.0.0:8080"

var db *sql.DB

func main() {
	fmt.Println("backend server starting")

	var err error

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL environment variable not set")
	}

	db, err = sql.Open("postgres", databaseURL)
	if err != nil {
		log.Fatalf("error connecting to database: %v", err)
	}
	defer db.Close()

	err = db.Ping()
	if err != nil {
		log.Fatalf("error pinging database: %v", err)
	}

	mux := http.NewServeMux()
	path, handler := v1connect.NewWeatherControlServiceHandler(&weatherControlServiceServer{})
	mux.Handle(path, withCORS(handler))
	err = http.ListenAndServe(
		address,
		h2c.NewHandler(mux, &http2.Server{}),
	)
	fmt.Println(err)
}

type weatherControlServiceServer struct {
	v1connect.UnimplementedWeatherControlServiceHandler
}

func (s *weatherControlServiceServer) GetWeather(
	ctx context.Context,
	req *connect.Request[v1.GetWeatherRequest],
) (*connect.Response[v1.GetWeatherResponse], error) {
	fmt.Println("GetWeather endpoint called")

	weatherType := "Sunny"
	intensity := 1

	err := db.QueryRow("SELECT weathertype, intensity FROM Weather ORDER BY Timestamp DESC LIMIT 1").Scan(&weatherType, &intensity)
	if err != nil {
		if err == sql.ErrNoRows {
			log.Println("using default value for response")
			return connect.NewResponse(&v1.GetWeatherResponse{
				WeatherType: "Sunny",
				Intensity:   1,
			}), nil
		}
		return nil, fmt.Errorf("error querying weather: %w", err)
	}

	return connect.NewResponse(&v1.GetWeatherResponse{
		WeatherType: weatherType,
		Intensity:   int32(intensity),
	}), nil
}

func (s *weatherControlServiceServer) SetWeather(
	ctx context.Context,
	req *connect.Request[v1.SetWeatherRequest],
) (*connect.Response[v1.SetWeatherResponse], error) {
	fmt.Println("SetWeather endpoint called")

	if req.Msg.WeatherType == "" || req.Msg.Intensity < 1 || req.Msg.Intensity > 10 {
		return connect.NewResponse(&v1.SetWeatherResponse{
			Success: false,
		}), fmt.Errorf("error: WeatherType must not be empty, and Intensity must be between 1 and 10")
	}

	_, err := db.Exec("INSERT INTO Weather (weathertype, intensity) VALUES ($1, $2)", req.Msg.WeatherType, req.Msg.Intensity)
	if err != nil {
		return connect.NewResponse(&v1.SetWeatherResponse{
			Success: false,
		}), fmt.Errorf("error inserting weather: %w", err)
	}

	return connect.NewResponse(&v1.SetWeatherResponse{
		Success: true,
	}), nil
}

func withCORS(connectHandler http.Handler) http.Handler {
	c := cors.New(cors.Options{
		AllowedMethods: connectcors.AllowedMethods(),
		AllowedHeaders: connectcors.AllowedHeaders(),
		ExposedHeaders: connectcors.ExposedHeaders(),
		MaxAge:         7200, // 2 hours in seconds
	})
	return c.Handler(connectHandler)
}
