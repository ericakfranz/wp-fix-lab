<?php
/**
 * Plugin Name: {{NAME}} (must-use)
 */
add_action( 'wp_head', function () {
	$seo = null;
	echo $seo->render_tags();
} );
