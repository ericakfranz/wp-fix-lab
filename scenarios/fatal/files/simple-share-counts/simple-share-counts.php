<?php
/**
 * Plugin Name: Simple Share Counts
 * Description: Shows social share counts under posts. Requires "Share Counts Core".
 * Version: 2.3.1
 */
add_action( 'init', function () {
	if ( defined( 'WP_CLI' ) && WP_CLI ) {
		return; // don't fatal during CLI; this lab breaks the web front end
	}
	// ssc_core_get_counts() lived in the "Share Counts Core" plugin, now deleted.
	$GLOBALS['ssc_counts'] = ssc_core_get_counts( get_option( 'ssc_networks', array( 'facebook' ) ) );
} );
add_filter( 'the_content', function ( $c ) {
	if ( ! empty( $GLOBALS['ssc_counts'] ) ) {
		$c .= '<p class="ssc">Shared ' . (int) array_sum( $GLOBALS['ssc_counts'] ) . ' times</p>';
	}
	return $c;
} );
