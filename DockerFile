FROM php:8.2-fpm

# Install system dependencies + Node.js
RUN apt-get update && apt-get install -y \
    git \
    curl \
    zip \
    unzip \
    gnupg \
    libpq-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    libssl-dev \
    && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && docker-php-ext-install pdo pdo_pgsql mbstring zip bcmath xml \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy the rest of the application
COPY . .

# Install PHP dependencies
RUN composer install --no-dev --no-interaction --optimize-autoloader

# Environment configuration
RUN cp .env.example .env && \
    sed -i 's/APP_DEBUG=.*/APP_DEBUG=false/' .env && \
    echo "DB_CONNECTION=pgsql" >> .env && \
    echo "DB_HOST=db" >> .env && \
    echo "DB_PORT=5432" >> .env && \
    echo "DB_DATABASE=laravel_db" >> .env && \
    echo "DB_USERNAME=laravel" >> .env && \
    echo "DB_PASSWORD=secret" >> .env

# Install Node.js dependencies and build assets
RUN npm install && \
    npm run build && \
    rm -rf node_modules

# Set proper permissions (fix for Vite assets issue)
RUN chown -R www-data:www-data /var/www && \
    find /var/www -type d -exec chmod 755 {} \; && \
    find /var/www -type f -exec chmod 644 {} \; && \
    chmod -R 777 storage bootstrap/cache

# Generate APP_KEY and optimize
RUN php artisan key:generate && \
    php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache

# Configure PHP-FPM
RUN sed -i 's|listen = 127.0.0.1:9000|listen = 9000|' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|;listen.owner = www-data|listen.owner = www-data|' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|;listen.group = www-data|listen.group = www-data|' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|user = www-data|user = www-data|' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|group = www-data|group = www-data|' /usr/local/etc/php-fpm.d/www.conf

EXPOSE 9000

CMD ["php-fpm"]