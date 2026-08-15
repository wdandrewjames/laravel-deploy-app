# shabang
#!bin/bash

# run composer ci:check
output=$(composer run ci:check 2>&1)
if [ $? -ne 0 ]; then                                                                                              
    echo "$output"
    echo "CI checks failed. Aborting deploy."
    exit 1
fi 

# put application into maintenance mode
ssh test-server "cd /var/www/vhosts/laravel-deploy-app && [ -f artisan ] && php artisan down || echo 'First deploy, skipping maintenance mode.'"  

# sync code
rsync -av --delete --filter=':- .gitignore' --exclude='.git' ./ test-server:/var/www/vhosts/laravel-deploy-app/ 

# ssh block
#migrate database, terminate horizon, npm run build
ssh test-server << 'EOF'
    cd /var/www/vhosts/laravel-deploy-app
    export COMPOSER_ALLOW_SUPERUSER=1 
    composer install --no-dev --optimize-autoloader
    php artisan migrate --force
    source ~/.nvm/nvm.sh
    npm ci
    npm run build
    php artisan up
EOF