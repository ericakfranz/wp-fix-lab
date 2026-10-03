<?php
/**
 * Plugin Name: Legacy Helpers (must-use)
 * A harmless-looking helper with a syntax error introduced by a bad paste.
 */
add_filter( 'the_content', function ( $content ) {
	$suffix = '<!-- rendered by legacy-helpers -->'
	return $content . $suffix;
} );
