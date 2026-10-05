<?php
/**
 * Plugin Name: {{NAME}}
 * Description: {{NAME}} adds extra features to your site.
 * Version: 1.4.2
 */
add_action( 'init', function () {
	if ( defined( 'WP_CLI' ) && WP_CLI ) { return; }
	{{FN}}();
} );
