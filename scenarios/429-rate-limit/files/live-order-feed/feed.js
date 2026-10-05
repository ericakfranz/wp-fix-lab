( function () {
	var cfg = window.liveOrderFeed;
	if ( ! cfg ) { return; }
	setInterval( function () {
		var body = new URLSearchParams( { action: 'lof_poll' } );
		fetch( cfg.ajaxUrl, { method: 'POST', body: body, credentials: 'same-origin' } )
			.then( function ( r ) { return r.ok ? r.json() : null; } )
			.then( function ( data ) { if ( data && data.success ) { console.log( '[LOF]', data.data.latest ); } } )
			.catch( function () {} );
	}, cfg.interval );
} )();
