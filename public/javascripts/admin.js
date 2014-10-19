$(document).ready(function(){
    $('.approve').click(function(){
        var id = $(this).attr('id');
        var url = '/securities/approve';
        var posting = $.post(url,{security: id});
        posting.always(function(data){
            window.location.reload(true); 
        });
    });
    $('.decline').click(function(){
        var id = $(this).attr('id');
        var url = '/securities/decline';
        var posting = $.post(url,{security: id});
        posting.always(function(data){
            window.location.reload(true); 
        });
    });
});