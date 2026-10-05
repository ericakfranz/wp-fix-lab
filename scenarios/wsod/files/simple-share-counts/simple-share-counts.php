<?php
/**
 * Plugin Name: Simple Share Counts
 * Description: Shows social share counts under posts. Requires the Share Counts Core plugin.
 * Version: 2.3.1
 */

// Load the counter early so counts are cached before the page renders.
add_action( 'init', function () {
	// Provided by the "Share Counts Core" plugin.
	$GLOBALS['ssc_counts'] = ssc_core_get_counts( get_option( 'ssc_networks', array( 'facebook', 'x' ) ) );
} );

add_filter( 'the_content', function ( $content ) {
	if ( ! is_singular( 'post' ) || empty( $GLOBALS['ssc_counts'] ) ) {
		return $content;
	}
	return $content . '<p class="ssc-counts">Shared ' . (int) array_sum( $GLOBALS['ssc_counts'] ) . ' times</p>';
} );
