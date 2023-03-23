/*global jQuery, window, document, self, encodeURIComponent */
var ProgressBar = (function($, window) {

  "use strict";

  var _private = {

    identifier: "",

    init: function(identifier, path = "user") {
      this.identifier = typeof identifier !== 'undefined' ? identifier : "";
      this.path = path;
      return this.candidate_counter();
    },

    candidate_counter: function() {
      var self = this, denominator, percent, message, progress_bar = $('#progress-bar_' + this.identifier),
          path = (this.path == "user") ? "" : this.path + "/";
      return $.ajax({
          method: "GET",
          url: "/" + path + self.identifier + "/progress.json"
        }).done(function(data) {
          denominator = data.claimed + data.unclaimed;
          if (denominator === 0) {
            percent = 100;
            message = "None";
          } else {
            percent = parseInt(100 * data.claimed / denominator, 10);
            message = percent + "%";
          }
          progress_bar.width(percent + '%').text(message);
          if (message === "None") {
            progress_bar.removeClass("bg-info").addClass("bg-secondary");
          }
          if (percent === 100 && denominator > 0) {
            progress_bar.removeClass("bg-info").addClass("bg-success");
          }
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
    init: function(identifier, path) {
      return _private.init(identifier, path);
    },
    forEachParallel: function(arr, func, threads) {
      return _private.forEachParallel(arr, func, threads);
    }
  };

}(jQuery, window));
