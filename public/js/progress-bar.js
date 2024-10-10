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
          badge = $('#specimen-counter-' + this.identifier),
          path = (this.path == "user") ? "" : this.path + "/";
      return $.ajax({
          method: "GET",
          url: "/" + path + self.identifier + "/progress.json"
        }).done(function(data) {

          if (badge.length) {
            if (data.unclaimed > 0 && data.unclaimed <= 50) {
              badge.text(data.unclaimed).show();
            } else if (data.unclaimed > 50) {
              badge.text("50+").show();
            }
          }

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
    }
  };

  return {
    init: function(identifier, path) {
      return _private.init(identifier, path);
    }
  };

}(jQuery, window));
