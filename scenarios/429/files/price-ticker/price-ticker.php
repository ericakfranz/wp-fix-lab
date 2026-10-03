<?php
/**
 * Plugin Name: Price Ticker
 * Description: Rotating price ticker. Polls admin-ajax on a configurable interval.
 * Version: 2.1.0
 */
function pt_interval_ms() { return max( 1, (int) get_option( 'priceticker_interval', 10 ) ) * 1000; }
function pt_assets() {
	wp_enqueue_script( 'lab-poll', plugins_url( '../poll.js', __FILE__ ), array(), '1', true );
	wp_localize_script( 'lab-poll', 'priceTicker', array(
		'ajaxUrl' => admin_url( 'admin-ajax.php' ), 'action' => 'pt_poll', 'interval' => pt_interval_ms(),
	) );
}
add_action( 'wp_enqueue_scripts', 'pt_assets' );
add_action( 'admin_enqueue_scripts', 'pt_assets' );
add_action( 'wp_ajax_pt_poll', function () { wp_send_json_success( 'ok' ); } );
add_action( 'wp_ajax_nopriv_pt_poll', function () { wp_send_json_success( 'ok' ); } );
