# Use nginx image
FROM nginx:alpine

# Copy dist to Nginx's html directory
COPY /dist /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
