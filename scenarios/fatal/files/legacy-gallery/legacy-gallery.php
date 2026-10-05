<?php
/**
 * Plugin Name: Legacy Gallery
 * Description: An old gallery plugin. Uses create_function(), which was removed in PHP 8.
 * Version: 1.0.0
 */
add_action( 'init', function () {
	if ( defined( 'WP_CLI' ) && WP_CLI ) {
		return; // don't fatal during CLI activation; this breaks the web front end
	}
	// create_function() was removed in PHP 8.0 -> "Call to undefined function".
	$cb = create_function( '$x', 'return $x;' );
	echo $cb( 1 );
} );
