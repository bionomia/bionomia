/*global jQuery, window, document, self, encodeURIComponent */
var ProgressBarAdd = (function($, window) {

   "use strict";
 
   var _private = {
 
     identifier: "",
 
     init: function(identifier) {
       this.identifier = typeof identifier !== 'undefined' ? identifier : "";
       this.ajax_setup();
       return this.add_user();
     },

     ajax_setup: function() {
       $.ajaxSetup({
         headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') }
       });
     },

     format_user_link: function(data) {
      var link = "";
      if (data.identifier[0] == "Q") {
         link += "<img src=\"/images/wikidata_18x12.svg\" alt=\"Wikidata iD\" class=\"mr-1\">";
      } else {
         link += "<i class=\"fab fa-orcid\"></i>";
      }
      link += "<a href=\"/help-others/" + data.identifier + "\">" + data.fullname + "</a>";
      return link;
     },

     format_unsuccessful: function() {
      var html = "";
      if (typeof Handlebars !== 'undefined' && $("#failed-result").length > 0) {
         html = Handlebars.compile($("#failed-result").html());
      }
      return html; 
     },

     tooltips: function() {
         $('[data-toggle="tooltip"]').tooltip();
         $('[data-toggle="tooltip"]', 'nav').on("mouseenter", function() {
         if ($(this).find("span").is(":visible")) {
            $(this).tooltip('hide');
         }
         }).on("focus", function() {
         $(this).tooltip('hide');
         });
     },

     add_user: function() {
       var self = this, progress_bar = $(".progress div[data-identifier='" + this.identifier + "']");
       return $.ajax({
           method: "POST",
           url: "/help-others/add-user.json",
           dataType: "json",
           data: JSON.stringify({
            identifier: this.identifier
           })
         }).done(function(data) {
            if (data.identifier) {
               progress_bar.width('100%');
               progress_bar.removeClass("bg-info").addClass("bg-success");
               progress_bar.parent().parent().next().html(self.format_user_link(data));
            } else {
               progress_bar.width('100%');
               progress_bar.removeClass("bg-info").addClass("bg-danger");
               progress_bar.parent().parent().next().html(self.format_unsuccessful());
            }
            self.tooltips();
         });
     },
 
     forEachParallel: function(arr, func, threads) {
       if (!$.isArray(arr)) throw new TypeError('First parameter must be an array');
       if (!$.isFunction(func)) throw new TypeError('Second parameter must be a function');
       if (!$.isNumeric(threads)) throw new TypeError('Third parameter must be a number');
   
       // The number of threads must be an integer
       threads = parseInt(threads);
   
       let masterDeferred = new $.Deferred();
       // To hold the result of each func(arr[i]) call
       let results = [];
       // To hold the deferreds that must be resolved before resolving masterDeferred
       let processes = [];
       let percentComplete = 0;
   
       // Map the input arr into an array of objects to preserve the index information.
       let queue = arr.map((value, index) => ({index, value}))
  
       // Create a new "process" for each item in the queue, up to the thread limit
       for (let i = 0; i < Math.min(queue.length, threads); i++) {
           // Note: Don't blindly change `let` to `var` here or this will break
           // this depends on block scoping.
           let process = new $.Deferred();
           processes.push(process.promise());
   
           (function next() {
               // Get the next item in the queue
               let item = queue.shift();
               if (!item) {
                   // If no items were found, this process is done.
                   process.resolve();
                   return;
               }
   
               // Call the function with the value at this index
               func(item.value)
                   // Then update the results with the result
                   .done(result => results[item.index] = result)
                   .done(() => {
                       // Update percentage, calling any progress listeners
                       let newPercentage = Math.floor((arr.length - queue.length) * 100 / arr.length);
                       if (newPercentage > percentComplete) {
                           percentComplete = newPercentage;
                           masterDeferred.notify(percentComplete);
                       }
                       // Loop
                       next();
                   });
           }());
       }
   
       // Resolve the returned deferred value once processing is complete
       $.when(...processes).done(() => masterDeferred.resolve(results))
   
       return masterDeferred.promise();
     }
   };
 
   return {
     init: function(identifier) {
       return _private.init(identifier);
     },
     forEachParallel: function(arr, func, threads) {
       return _private.forEachParallel(arr, func, threads);
     }
   };
 
 }(jQuery, window));
 