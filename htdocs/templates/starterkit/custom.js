jQuery(document).ready(function() {
   $("#orderedlist").addClass("red");
   $("#orderedlist > li").addClass("blue");
   $("#orderedlist li:last").hover(function() {
     $(this).addClass("green");
   },function(){
     $(this).removeClass("green");
   });
   $("#orderedlist").find("li").each(function(i) {
     $(this).append( " BAM! " + i );
   });
   //$("#reset").click(function() {
   //  $("form")[0].reset();
   //});
   $("#reset").click(function() {
     $("form").each(function() {
       this.reset();
     });
   });
   $("li").not(":has(ul)").css("border", "1px solid black");
   $("a[name]").css("background", "#eee" );
   //$('#faq').find('dd').hide().end().find('dt').click(function() {
   //  $(this).next().slideToggle();
   });
});
