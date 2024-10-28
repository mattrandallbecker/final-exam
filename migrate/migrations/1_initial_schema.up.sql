CREATE TABLE Weather (
    WeatherType VARCHAR(255),
    Intensity INTEGER,
    Timestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);
