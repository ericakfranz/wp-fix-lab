<?php
/**
 * Plugin Name: Live Order Feed
 * Description: Real-time "someone just ordered" popups for visitors and a live order ticker for staff.
 * Version: 1.0.4
 */

// Polling interval in seconds. Settings page "coming soon"; for now it's an option.
function lof_interval_ms() {
	return max( 1, (int) get_option( 'lof_poll_interval', 1 ) ) * 1000;
}

function lof_enqueue() {
	wp_enqueue_script( 'live-order-feed', plugins_url( 'feed.js', __FILE__ ), array(), '1.0.4', true );
	wp_localize_script( 'live-order-feed', 'liveOrderFeed', array(
		'ajaxUrl'  => admin_url( 'admin-ajax.php' ),
		'interval' => lof_interval_ms(),
	) );
}
add_action( 'wp_enqueue_scripts', 'lof_enqueue' );
add_action( 'admin_enqueue_scripts', 'lof_enqueue' );

function lof_poll() {
	wp_send_json_success( array( 'latest' => 'Someone in Portland just ordered a sourdough loaf' ) );
}
add_action( 'wp_ajax_lof_poll', 'lof_poll' );
add_action( 'wp_ajax_nopriv_lof_poll', 'lof_poll' );
