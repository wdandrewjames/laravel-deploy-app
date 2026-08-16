#!/bin/bash

# run composer ci:check
output=$(composer run ci:check 2>&1)
if [ $? -ne 0 ]; then                                                                                              
    echo "$output"
    echo "CI checks failed. Aborting deploy."
    exit 1
fi 

# put application into maintenance mode
ssh test-server-deploy "cd /var/www/vhosts/laravel-deploy-app && [ -f artisan ] && php artisan down || echo 'First deploy, skipping maintenance mode.'"  

# sync code
rsync -av \
    --delete \
    --exclude='.git/' \
    --exclude='.phpunit.cache/' \
    --exclude='bootstrap/ssr/' \
    --exclude='bootstrap/cache/' \
    --exclude='node_modules/' \
    --exclude='public/build/' \
    --exclude='public/hot' \
    --exclude='storage/' \
    --exclude='public/storage/' \
    --exclude='storage/*.key' \
    --exclude='storage/pail/' \
    --exclude='resources/js/actions/' \
    --exclude='resources/js/routes/' \
    --exclude='resources/js/wayfinder/' \
    --exclude='vendor/' \
    --exclude='.env' \
    --exclude='.env.backup' \
    --exclude='.env.production' \
    --exclude='.env.testing' \
    ./ test-server-deploy:/var/www/vhosts/laravel-deploy-app/ 

# ssh block
#migrate database, terminate horizon, npm run build
ssh test-server-deploy << 'EOF'
    set -e
    cd /var/www/vhosts/laravel-deploy-app
    mkdir -p bootstrap/cache storage/framework/{sessions,views,cache} storage/logs
    composer install --no-dev --optimize-autoloader
    php artisan migrate --force
    source /home/deploy/.nvm/nvm.sh
    npm ci
    npm run build
    php artisan optimize
    php artisan up
EOF