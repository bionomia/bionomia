/*global jQuery, window, document, self, encodeURIComponent, Bootstrap */

var Profile = (function($, window) {

  "use strict";

  var _private = {

    user_id: "",
    path: "",

    init: function(path) {
      this.path = typeof path !== 'undefined' ? path : "/profile";
      this.activate_validation();
      this.activate_profile_image();
      this.activate_zenodo();
      this.activate_email();
      this.message_counter();
    },

    activate_validation: function() {
      // Fetch all the forms we want to apply custom Bootstrap validation styles to
      var forms = document.getElementsByClassName('needs-validation');
      // Loop over them and prevent submission
      var validation = Array.prototype.filter.call(forms, function(form) {
        form.addEventListener('submit', function(event) {
          if (form.checkValidity() === false) {
            event.preventDefault();
            event.stopPropagation();
          }
          form.classList.add('was-validated');
        }, false);
      });
    },

    activate_profile_image: function() {
      var popup = $('#profile-upload-option'), self = this;

      $('#profile-image').on('click', function(e) {
        e.stopPropagation();
        popup.show();
      });
      $('#profile-image a').on('click', function(e) {
        e.stopPropagation();
        e.preventDefault();
        popup.show();
      });
      $('#profile-cancel').on('click', function(e) {
        e.stopPropagation();
        e.preventDefault();
        popup.hide();
      });
      $('#profile-remove').on('click', function(e) {
        e.stopPropagation();
        e.preventDefault();
        popup.hide();
        $('#profile-image').addClass("profile-image-bg")
                           .find("img").attr({width:"0px", height:"0px"})
                           .attr({src:"/images/photo.png", width:"48px", height:"96px"});
        $.ajax({
          url: self.path + '/image',
          data: {},
          type: 'DELETE'
        }).done(function(data) {
          location.reload();
        });
      });
      $('#user-image').on('change', function(e) {
        popup.hide();
        if (e.target.files[0]) {
          var reader = new FileReader();
          reader.onload = function(e) {
            var image = new Image();
            image.src = e.target.result;
            image.onload = function() {
              var dimensions = self.calculateAspectRatioFit(image.width, image.height);
              $('#profile-image').removeClass("profile-image-bg")
                                 .find("img")
                                 .attr({
                                   src:e.target.result,
                                   width:dimensions.width+"px",
                                   height:dimensions.height+"px",
                                   class:"upload-preview"
                                 });
              };
          };
          reader.readAsDataURL(e.target.files[0]);
          var data = new FormData();
          data.append('file', $('#user-image')[0].files[0]);
          $.ajax({
              url: self.path + '/image',
              data: data,
              processData: false,
              type: 'POST',
              contentType: false,
              cache: false
          }).done(function(data) {
            var response = JSON.parse(data);
            if (response.message === "ok") {
              location.reload();
            } else {
              $('#profile-image').find("img").remove();
              $('#image-alert').addClass("show").show().on('close.bs.alert', function() {
                $('#profile-remove').trigger("click");
              });
              setTimeout(function() { location.reload(); }, 2500);
            }
          }).fail(function(data) {
            $('#profile-image').find("img").remove();
            $('#image-alert').addClass("show").show().on('close.bs.alert', function() {
              $('#profile-remove').trigger("click");
            });
          });
        }
      });
    },

    activate_email: function() {
      var self = this;
      $("#toggle-mail").on("change", function() {
        $.ajax({
          method: "PUT",
          url: self.path + "/settings",
          dataType: "json",
          contentType: "application/json",
          data: JSON.stringify({
            wants_mail: $(this).prop("checked"),
            youtube_id: $("#youtube_id").val(),
            locale: $('#locale').val()
          }),
          beforeSend: function(xhr) {
            $(this).addClass("disabled");
          }
        }).done(function(data) {
          location.reload();
        });
        return false;
      });
    },

    activate_zenodo: function() {
      var self = this;
      $('#zenodo-disconnect').on('click', function() {
        $.ajax({
          url: '/auth/zenodo',
          method: 'DELETE',
          type: 'DELETE',
          data: {}
        }).done(function(data) {
          $('#zenodoModal').modal('hide');
          location.reload();
        });
      });
      $('#zenodo-submit').on('click', function(e) {
        var button = $(this);
        e.stopPropagation();
        e.preventDefault();
        $.ajax({
          url: self.path + "/zenodo.json",
          method: 'PUT',
          contentType: "application/json",
          dataType: "json",
          data: JSON.stringify({ action: $(this).attr("data-action") }),
          beforeSend: function(xhr) {
            button.addClass("disabled");
          }
        }).done(function(data) {
          //Perhaps something here for the db
        });
      });
    },

    message_counter: function() {
      var self = this;
      $.ajax({
        method: "GET",
        url: self.path + "/message-count.json"
      }).done(function(data) {
        if (data.count > 0 && data.count <= 50) {
          $("#message-counter").text(data.count).show();
        } else if (data.count > 50) {
          $(".badge-notify-message").text("50+").show();
        }
      });
    },

    calculateAspectRatioFit: function(srcWidth, srcHeight) {
      var ratio = 1;
      if (srcWidth > 250 || srcHeight > 250) {
        ratio = Math.min(250/srcWidth, 250/srcHeight);
      }
      return { width: srcWidth*ratio, height: srcHeight*ratio };
     }
  };

  return {
    init: function(path) {
      _private.init(path);
    }
  };

}(jQuery, window));
