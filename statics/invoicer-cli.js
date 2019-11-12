
function getQueryParams(qs) {
    qs = qs.split("+").join(" ");
    var params = {},
        tokens,
        re = /[?&]?([^=]+)=([^&]*)/g;

    while (tokens = re.exec(qs)) {
        params[decodeURIComponent(tokens[1])]
            = decodeURIComponent(tokens[2]);
    }
    return params;
}
var $_GET = getQueryParams(document.location.search);

$(document).ready(function() {
	var invoiceid = $_GET['invoiceid'];
	if (invoiceid == undefined) {
		invoiceid = "1";
	}
    getInvoice(invoiceid, "undef");
});

$(document).ready(function() {
    $("form#invoiceGetter").submit(function(event) {
        event.preventDefault();
        getInvoice($("#invoiceid").val(), $("#CSRFToken").val());
	});
});

function getInvoice(invoiceid, CSRFToken) {
	$('.desc-invoice').html("<p>Showing invoice ID " + invoiceid + "</p>");
	$.ajax({
	url: "/invoice/delete/" + invoiceid,
	beforeSend: function (request) {
		request.setRequestHeader(
		"X-CSRF-Token",
		$("#CSRFToken").val());
	}
	}).then( function(resp) {
	$('.invoice-details').text(resp);
	});
}

