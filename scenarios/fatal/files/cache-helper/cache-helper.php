<?php
/**
 * Plugin Name: Cache Helper
 * Description: Adds a tiny cache-control header. Harmless. (Red herring.)
 * Version: 1.2.0
 */
add_action( 'send_headers', function () {
	header( 'X-Cache-Helper: on' );
} );
