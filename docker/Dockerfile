# Use the official NGINX base image
FROM nginx:latest

# Remove the default NGINX welcome page
RUN rm -rf /usr/share/nginx/html/*

# Copy the custom welcome page
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80
EXPOSE 80

# Start NGINX
CMD ["nginx", "-g", "daemon off;"]
