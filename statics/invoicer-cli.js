
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
    getInvoice(invoiceid);
});

$(document).ready(function() {
    $("form#invoiceGetter").submit(function(event) {
        event.preventDefault();
        getInvoice($("#invoiceid").val());
	});
});

function getInvoice(invoiceid) {
    $('.desc-invoice').text("Showing invoice ID " + invoiceid);
    $.ajax({
        url: "/invoice/" + invoiceid,
        error: function (xhr, ajaxOptions, thrownError) {
            if(xhr.status==404) {
                $('.invoice-details').text("invoice not found");
                return;
            }
        }
    }).then(function(invoice) {
        $('.invoice-details').text("Invoice ID " + invoice.ID + " has amount $" + invoice.amount);
    });
}
