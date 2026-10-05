<?php
/**
 * Plugin Name: Stock Pinger
 * Description: Live stock badges. Has a "poll interval" setting... that it ignores.
 * Version: 0.9.0
 */
// Looks configurable - but the interval below is hard-coded, so changing this does nothing.
add_action( 'init', function () { add_option( 'stpg_interval', 5 ); } );
function stpg_assets() {
	wp_enqueue_script( 'lab-poll', plugins_url( '../poll.js', __FILE__ ), array(), '1', true );
	wp_localize_script( 'lab-poll', 'stockPinger', array(
		'ajaxUrl' => admin_url( 'admin-ajax.php' ), 'action' => 'stpg_poll', 'interval' => 1000, // hard-coded 1s
	) );
}
add_action( 'wp_enqueue_scripts', 'stpg_assets' );
add_action( 'admin_enqueue_scripts', 'stpg_assets' );
add_action( 'wp_ajax_stpg_poll', function () { wp_send_json_success( 'ok' ); } );
add_action( 'wp_ajax_nopriv_stpg_poll', function () { wp_send_json_success( 'ok' ); } );
