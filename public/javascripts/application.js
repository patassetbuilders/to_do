// application.js
console.log("This is a test");

  $(function(){
    $("form.delete").submit(function(event) {
      event.preventDefault();
      event.stopPropagation();
      
      var ok = confirm("Are you sure? This cannot be undone");
      if (ok){
        this.submit();
      }
    });
  });