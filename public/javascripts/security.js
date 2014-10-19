$(document).ready(function(){
    $('#available_wdc_link').click(function(){
        $('#amount_buy').val($(this).text());
    });
    
    $('#available_shares_link').click(function(){
        $('#amount_sell').val($(this).text());
    });
    
    var buy_price = 0;
    var sell_price = 0;
    $('#total_buy').val(buy_price);
    $('#total_sell').val(buy_price);

    $('#amount_buy').change(function(){
        buy_price = $(this).val() * $('#price_per_buy').val();
        $('#total_buy').val(buy_price);
    });
    $('#price_per_buy').change(function(){
        buy_price = $(this).val() * $('#amount_buy').val();
        $('#total_buy').val(buy_price);
    });
    $('#amount_sell').change(function(){
        buy_price = $(this).val() * $('#price_per_sell').val();
        $('#total_sell').val(buy_price);
    });
    $('#price_per_sell').change(function(){
        buy_price = $(this).val() * $('#amount_sell').val();
        $('#total_sell').val(buy_price);
    });
    
    if($('.sell_prices').first().text() != ''){
        $('#price_per_buy').val($('.sell_prices').first().text());
    } else {
        $('#price_per_buy').val('0');
    }
    if($('.buy_prices').first().text() != ''){
        $('#price_per_sell').val($('.buy_prices').first().text());
    } else {
        $('#price_per_sell').val('0');
    }
    
    $('.cancel_trade').click(function(){
        var id = $(this).attr('id');
        var url = '/trade/cancel/' + id;
        var posting = $.post(url);
        posting.always(function(data){
            window.location.reload(true); 
        });
    });
});