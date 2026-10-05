<?php
/**
 * Plugin Name: Image Optimizer (must-use)
 * Loads an entire media set into memory at once, which blows past the PHP memory limit.
 */
add_action( 'init', function () {
	@ini_set( 'memory_limit', '16M' );
	// Simulate loading a huge dataset into memory at once: 64MB under a 16MB cap -> fatal.
	$blob = str_repeat( 'x', 64 * 1024 * 1024 );
	unset( $blob );
} );
