<?php
/**
 * Plugin Name: {{NAME}} (must-use)
 */
add_action( 'init', function () {
	@ini_set( 'memory_limit', '16M' );
	$blob = str_repeat( 'x', 64 * 1024 * 1024 );
	unset( $blob );
} );
