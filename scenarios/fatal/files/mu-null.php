<?php
/**
 * Plugin Name: SEO Meta Writer (must-use)
 * Writes meta tags. Assumes an object that isn't there on PHP 8 -> fatal.
 */
add_action( 'wp_head', function () {
	$seo = null; // was populated by a global that no longer exists
	echo $seo->meta_tags(); // Error: Call to a member function meta_tags() on null
} );
