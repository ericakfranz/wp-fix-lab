<?php
/**
 * Plugin Name: {{NAME}} (must-use)
 */
add_filter( 'the_content', function ( $c ) {
	$suffix = '<!-- footer note -->'
	return $c . $suffix;
} );
