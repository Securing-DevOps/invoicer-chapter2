
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

// $(document).ready(function() {
//   $("form#invoiceDeleter").submit(function(event) {
//         event.preventDefault();
//         deleteInvoice($("#deleteInvoiceid").val(), $("#CSRFToken").val());
//   });
// });

function getInvoice(invoiceid, CSRFToken) {
    $('.desc-invoice').html("<p>Showing invoice ID " + invoiceid + "</p>");
    $.ajax({
        url: "/invoice/" + invoiceid,
        beforeSend: function (request)
        {
            //request.setRequestHeader("X-CSRF-Token", CSRFToken);
            request.setRequestHeader("X-CSRF-Token", CSRFToken);

        },
        error: function (xhr, ajaxOptions, thrownError) {
            if(xhr.status==404) {
                $('.invoice-details').html("<p>invoice not found</p>");
                return;
            }
        }
    }).then(function(invoice) {
        $('.invoice-details').html("<p>Invoice #" + invoice.ID + "<br />Amount: $" + invoice.amount + "<br />Type: " + invoice.charges[0].type + "<br />Description: '" + invoice.charges[0].description + "'</p>");
    });
}

// function deleteInvoice(invoiceid, CSRFToken) {
//     $('.desc-invoice').html("<p>Showing invoice ID " + invoiceid + "</p>");
//     $.ajax({
//         url: "/invoice/delete/" + invoiceid,
//         beforeSend: function (request)
//         {
//             //request.setRequestHeader("X-CSRF-Token", CSRFToken);
//             request.setRequestHeader("CSRFToken", CSRFToken);
//         },
//         error: function (xhr, ajaxOptions, thrownError) {
//             if(xhr.status==404) {
//                 $('.invoice-details').html("<p>invoice not found</p>");
//                 return;
//             }
//         }
//     }).then(function(invoice) {
//         $('.invoice-details').html("<p>Invoice #" + invoice.ID + " deleted ");
//     });
// }
