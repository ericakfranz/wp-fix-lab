<?php
/**
 * Plugin Name: Promo Popup
 * Description: Shows a promo popup to logged-out visitors and polls admin-ajax for the latest offer.
 * Version: 1.0.0
 */
function promo_assets() {
	if ( is_user_logged_in() ) {
		return; // only visitors get the popup, so a logged-in admin never sees the polling
	}
	wp_enqueue_script( 'lab-poll', plugins_url( '../poll.js', __FILE__ ), array(), '1', true );
	wp_localize_script( 'lab-poll', 'promoPopup', array(
		'ajaxUrl' => admin_url( 'admin-ajax.php' ), 'action' => 'promo_poll', 'interval' => 1000, // 1s
	) );
}
add_action( 'wp_enqueue_scripts', 'promo_assets' );
add_action( 'wp_ajax_promo_poll', function () { wp_send_json_success( 'ok' ); } );
add_action( 'wp_ajax_nopriv_promo_poll', function () { wp_send_json_success( 'ok' ); } );
