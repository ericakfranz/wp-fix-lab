( function () {
	var keys = ['liveOrderFeed','stockPinger','priceTicker','promoPopup'];
	keys.forEach( function ( k ) {
		var cfg = window[k];
		if ( ! cfg || ! cfg.ajaxUrl ) { return; }
		setInterval( function () {
			fetch( cfg.ajaxUrl + '?action=' + ( cfg.action || 'lab_poll' ), { credentials: 'same-origin' } ).catch( function () {} );
		}, cfg.interval );
	} );
} )();
