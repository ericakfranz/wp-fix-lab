<?php
/**
 * Plugin Name: {{NAME}}
 * Description: {{NAME}} shows live updates on the storefront.
 * Version: 2.0.1
 */
add_action( 'wp_footer', function () {
	{{GATE}}
	$ms = {{MS}};
	echo "\n<!--labpoll:{$ms}-->\n";
	echo '<script>setInterval(function(){fetch("' . admin_url( 'admin-ajax.php' ) . '?action={{ACTION}}").catch(function(){});},' . $ms . ');</script>';
} );
add_action( 'wp_ajax_{{ACTION}}', function () { wp_send_json_success( 'ok' ); } );
add_action( 'wp_ajax_nopriv_{{ACTION}}', function () { wp_send_json_success( 'ok' ); } );
