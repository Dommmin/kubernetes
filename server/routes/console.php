<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

use function Laravel\Prompts\info;

Artisan::command('inspire', function (): void {
    info(Inspiring::quote());
})->purpose('Display an inspiring quote');
