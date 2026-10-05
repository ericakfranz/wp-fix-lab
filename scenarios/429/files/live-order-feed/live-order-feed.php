<?php
/**
 * Plugin Name: Live Order Feed
 * Description: "Someone just ordered" popups. Polls admin-ajax on an interval you can set.
 * Version: 1.0.4
 */
function lof_interval_ms() { return max( 1, (int) get_option( 'lof_poll_interval', 1 ) ) * 1000; }
function lof_assets() {
	wp_enqueue_script( 'lab-poll', plugins_url( '../poll.js', __FILE__ ), array(), '1', true );
	wp_localize_script( 'lab-poll', 'liveOrderFeed', array(
		'ajaxUrl' => admin_url( 'admin-ajax.php' ), 'action' => 'lof_poll', 'interval' => lof_interval_ms(),
	) );
}
add_action( 'wp_enqueue_scripts', 'lof_assets' );
add_action( 'admin_enqueue_scripts', 'lof_assets' );
add_action( 'wp_ajax_lof_poll', 'lof_ping' );
add_action( 'wp_ajax_nopriv_lof_poll', 'lof_ping' );
function lof_ping() { wp_send_json_success( 'ok' ); }
