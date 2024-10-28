# use official migrate image
FROM migrate/migrate:v4.16.2 as migrate
# have to use multi-stage to add environment variables and files
FROM alpine:latest
# copy the binary, files, set connection string, and default command
COPY --from=migrate /usr/local/bin/migrate /usr/local/bin/
COPY . .
ENV DATABASE_URL='postgres://postgres:postgres@/postgres?host=host.docker.internal&sslmode=disable'
# run migrate up
CMD migrate -path /migrations -database "$DATABASE_URL" up
