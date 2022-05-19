/*global jQuery, window, document, self, encodeURIComponent, Bloodhound, Bootstrap, Filter */

Array.prototype.all_unique = function () {
  "use strict";
  return this.filter(function (value, index, self) {
    return self.indexOf(value) === index;
  });
};

jQuery.fn.preventDoubleSubmission = function() {
  $(this).on('submit',function(e){
    var $form = $(this);

    if ($form.data('submitted') === true) {
      e.preventDefault();
    } else {
      $form.data('submitted', true);
    }
  });
  return this;
};

var Application = (function($, window) {

  "use strict";

  var _private = {

    user_id: "",
    path: "",
    method: "POST",
    identifier: "",
    spinner: "<div class=\"spinner-grow\" role=\"status\"><span class=\"sr-only\">Loading...</span></div>",
    data_sources: { agent: {}, user : {}, organization : {} },

    init: function(user_id, method, path, identifier) {
      this.user_id = typeof user_id !== 'undefined' ? user_id : "";
      this.method = typeof method !== 'undefined' ? method : "POST";
      this.path = typeof path !== 'undefined' ? path : "";
      this.identifier = typeof identifier !== 'undefined' ? identifier : "";

      this.ajax_setup();
      this.profile_cards();
      this.bloodhound();
      this.typeahead();
      this.activate_dropdowns();
      this.activate_radios();
      this.activate_switch();
      this.activate_refresh();
      this.activate_popovers();
      this.candidate_counter();
      this.helper_navbar();
      this.helper_modal();
    },

    ajax_setup: function() {
      var jqxhrs = [];

      $.ajaxSetup({
        headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') }
      });

      $(window).bind("beforeunload", function (e) {
        $.each(jqxhrs, function (idx, jqxhr) {
          if (jqxhr) { jqxhr.abort(); }
        });
      });
      var register_xhr = function(e, jqxhr, settings) {
        jqxhrs.push(jqxhr);
      };
      var unregister_xhr = function(e, jqxhr, settings) {
        var idx = $.inArray(jqxhr, jqxhrs);
        jqxhrs.splice(idx, 1);
      };
      $(document).ajaxSend(register_xhr);
      $(document).ajaxComplete(unregister_xhr);
    },

    profile_cards: function() {
      $(".card-profile").on("click", function(e) {
        e.stopPropagation();
        window.location = $(this).find(".card-header a").attr("href");
      });
    },

    bloodhound: function() {
      this.data_sources.agent = this.create_bloodhound("agent");
      this.data_sources.agent.initialize();
      this.data_sources.user = this.create_bloodhound("user");
      this.data_sources.user.initialize();
      this.data_sources.organization = this.create_bloodhound("organization");
      this.data_sources.organization.initialize();
      this.data_sources.dataset = this.create_bloodhound("dataset");
      this.data_sources.dataset.initialize();
      this.data_sources.taxon = this.create_bloodhound("taxon");
      this.data_sources.taxon.initialize();
    },

    create_bloodhound: function(type) {
      return new Bloodhound({
        datumTokenizer : Bloodhound.tokenizers.whitespace,
        queryTokenizer : Bloodhound.tokenizers.whitespace,
        sufficient : 10,
        remote : {
          url : "/"+type+".json?q=%QUERY",
          wildcard : "%QUERY",
          rateLimitWait: 500,
          transform : function(r) {
            return $.map(r, function (v) { v.type = type; return v; });
          }
        }
      });
    },

    typeahead: function(){
      var self = this,
          user_template = (typeof Handlebars !== 'undefined' && $("#result-template").length > 0) ? Handlebars.compile($("#result-template").html()) : "",
          user_empty = (typeof Handlebars !== 'undefined' && $("#empty-template").length > 0) ? Handlebars.compile($("#empty-template").html()) : "";

      $("#typeahead-agent").typeahead({
          minLength: 3,
          highlight: true
        },
        {
          name: "agent",
          limit: 10,
          source : this.data_sources.agent.ttAdapter(),
          display : "fullname_reverse"
        }
        ).on("typeahead:select", function(obj, datum) {
          var datasetKey = (typeof Filters !== "undefined") ? Filters.datasetKey : "";
          var taxon_id = (typeof Filters !== "undefined") ? Filters.taxon_id : "";
          var kingdom = (typeof Filters !== "undefined") ? Filters.kingdom : "";

          if (self.path === "/admin") {
            window.location.href = "/admin/user/" + self.identifier + "/advanced-search?agent_id=" + datum.id + "&datasetKey=" + datasetKey + "&taxon_id=" + taxon_id + "&kingdom=" + kingdom;
          } else if (self.path === "/agents") {
            window.location.href = "/agent/" + datum.id;
          } else if (self.path === "/help-others") {
            window.location.href = "/help-others/" + self.identifier + "/advanced-search?agent_id=" + datum.id + "&datasetKey=" + datasetKey + "&taxon_id=" + taxon_id + "&kingdom=" + kingdom;
          } else {
            window.location.href = "/profile/advanced-search?agent_id=" + datum.id + "&datasetKey=" + datasetKey + "&taxon_id=" + taxon_id + "&kingdom=" + kingdom;
          }
        });

      $("#typeahead-user").typeahead({
          minLength: 3,
          highlight: true
        },
        {
          name: "user",
          limit: 10,
          source : this.data_sources.user.ttAdapter(),
          display : "fullname_reverse",
          templates: {
            suggestion: user_template,
            empty: user_empty
          }
        }
        ).on("typeahead:select", function(obj, datum) {
          var identifier = datum.orcid || datum.wikidata;
          if (self.path === "/admin") {
            window.location.href = "/admin/user/" + identifier;
          } else if (self.path === "/roster") {
            window.location.href = "/" + identifier;
          } else {
            window.location.href = "/help-others/" + identifier;
          }
        });

      $("#typeahead-organization").typeahead({
          minLength: 1,
          highlight: true
        },
        {
          name: "organization",
          source : this.data_sources.organization.ttAdapter(),
          display : "name"
        }
        ).on("typeahead:select", function(obj, datum) {
          if (self.path === "/admin") {
            window.location.href = "/admin/organization/" + datum.id;
          } else {
            window.location.href = "/organization/" + datum.preferred;
          }
        });

      $("#typeahead-dataset").typeahead({
          minLength: 1,
          highlight: true
        },
        {
          name: "dataset",
          limit: 10,
          source : this.data_sources.dataset.ttAdapter(),
          display : "title"
        }
        ).on("typeahead:select", function(obj, datum) {
          var agent_id = (typeof Filters !== "undefined") ? Filters.agent_id : "";
          var taxon_id = (typeof Filters !== "undefined") ? Filters.taxon_id : "";
          var kingdom = (typeof Filters !== "undefined") ? Filters.kingdom : "";
          if (self.path === "/admin" && !self.identifier) {
            window.location.href = "/admin/dataset/" + datum.datasetkey;
          } else if (self.path === "/admin" && self.identifier) {
            window.location.href = "/admin/user/" + self.identifier + "/advanced-search?agent_id=" + agent_id + "&datasetKey=" + datum.datasetkey + "&taxon_id=" + taxon_id + "&kingdom=" + kingdom;
          } else if (self.path === "/help-others") {
            window.location.href = "/help-others/" + self.identifier + "/advanced-search?agent_id=" + agent_id + "&datasetKey=" + datum.datasetkey + "&taxon_id=" + taxon_id + "&kingdom=" + kingdom;
          } else if (self.path === "/profile") {
            window.location.href = "/profile/advanced-search?agent_id=" + agent_id + "&datasetKey=" + datum.datasetkey + "&taxon_id=" + taxon_id + "&kingdom=" + kingdom;
          } else {
            window.location.href = "/dataset/" + datum.datasetkey;
          }
        });

        $("#typeahead-taxon").typeahead({
            minLength: 1,
            highlight: true
          },
          {
            name: "taxon",
            limit: 10,
            source : this.data_sources.taxon.ttAdapter(),
            display : "name"
          }
          ).on("typeahead:select", function(obj, datum) {
            var agent_id = (typeof Filters !== "undefined") ? Filters.agent_id : "";
            var datasetKey = (typeof Filters !== "undefined") ? Filters.datasetKey : "";
            var kingdom = (typeof Filters !== "undefined") ? Filters.kingdom : "";
            if (self.path === "/help-others") {
              window.location.href = "/help-others/" + self.identifier + "/advanced-search?agent_id=" + agent_id + "&datasetKey=" + datasetKey + "&taxon_id=" + datum.id + "&kingdom=" + kingdom;
            } else if (self.path === "/profile") {
              window.location.href = "/profile/advanced-search?agent_id=" + agent_id + "&datasetKey=" + datasetKey + "&taxon_id=" + datum.id + "&kingdom=" + kingdom;
            } else if (self.path === "/admin" && !self.identifier) {
              window.location.href = "/admin/taxon/" + datum.name;
            } else if (self.path === "/admin" && self.identifier) {
              window.location.href = "/admin/user/"+self.identifier+"/advanced-search?agent_id=" + agent_id + "&datasetKey=" + datasetKey + "&taxon_id=" + datum.id + "&kingdom=" + kingdom;
            } else if (self.path === "/taxa") {
              window.location.href = "/taxon/" + datum.name;
            } else {
              window.location.href = window.location.pathname + "?q=" + datum.name;
            }
          });
    },

    activate_dropdowns: function() {
      var self = this,
          agent_id = "",
          datasetKey = "",
          taxon_id = "",
          kingdom = "",
          country_code = "";

      $("a.expand-collapse").on("click", function(e) {
        var child = $(this).children().first();
        e.stopPropagation();
        e.preventDefault();
        if(child.hasClass("fa-angle-double-down")) {
          child.removeClass("fa-angle-double-down").addClass("fa-angle-double-up");
          $(this).parent().prev().css({"max-height":"100%"});
        } else {
          child.removeClass("fa-angle-double-up").addClass("fa-angle-double-down");
          $(this).parent().prev().css({"max-height":"300px"});
        }
      });

      $("#kingdom, #country").on("change", function() {
        if (typeof Filters !== "undefined") {
          agent_id = Filters.agent_id;
          datasetKey = Filters.datasetKey;
          taxon_id = Filters.taxon_id;
          kingdom = Filters.kingdom;
          country_code = Filters.country_code;
        }
        if(this.id == "country") {
          country_code = this.value;
        }
        if(this.id == "kingdom") {
          kingdom = this.value;
        }
        if (self.path === "/help-others") {
          window.location.href = "/help-others/" + self.identifier + "/advanced-search?agent_id=" + agent_id +"&taxon_id=" + taxon_id + "&datasetKey=" + datasetKey + "&kingdom=" + kingdom + "&country_code=" + country_code;
        } else if (self.path === "/profile") {
          window.location.href = "/profile/advanced-search?agent_id=" + agent_id + "&datasetKey=" + datasetKey + "&taxon_id=" + taxon_id + "&kingdom=" + kingdom + "&country_code=" + country_code;
        } else if (self.path === "/admin") {
          window.location.href = "/admin/user/"+self.identifier+"/advanced-search?agent_id=" + agent_id + "&datasetKey=" + datasetKey + "&taxon_id=" + taxon_id + "&kingdom=" + kingdom + "&country_code=" + country_code;
        }
      });
    },

    activate_switch: function() {
      $("#toggle-public").on("change", function() {
        $.ajax({
          method: "PUT",
          url: $(this).attr("data-url"),
          dataType: "json",
          data: JSON.stringify({ is_public: $(this).prop("checked") })
        }).done(function(data) {
          location.reload();
        });
        return false;
      });
    },

    activate_radios: function(){
      var self = this, url = "", identifier = "";

	    if (self.path === "/profile") {
	      url = self.path + "/candidates";
	    } else if (self.path === "/admin") {
        identifier = window.location.pathname.split("/")[3];
	      url = self.path + "/user/" + identifier + "/candidates";
	    } else if (self.path === "/help-others") {
        identifier = window.location.pathname.split("/")[2];
	      url = self.path + "/" + identifier;
	    }

      $("#relaxed").on("change", function() {
        url = new URL(window.location.href);
        if ($(this).prop("checked")) {
          url.searchParams.set('relaxed', 1);
          window.location.href = url.href;
        } else {
          url.searchParams.set('relaxed', 0);
          window.location.href = url.href;
        }
        return false;
      });

      $("input.action-radio").on("change", function() {
          var row = $(this).parents("tr"),
              action = $(this).attr("data-action"),
              label = $(this).parent(),
              input = $(this);

          if($(this).attr("name") === "selection-all") {
              var occurrence_ids = $.map($("[data-occurrence-id]:not(:disabled)"), function(e) {
                    return $(e).attr("data-occurrence-id");
                  }).all_unique().toString();
              if(!occurrence_ids.trim()) {
                return false;
              }
              $.ajax({
                  method: self.method,
                  url: self.path + "/user-occurrence/bulk.json",
                  dataType: "json",
                  data: JSON.stringify({
                    user_id: self.user_id,
                    occurrence_ids: occurrence_ids,
                    action: action,
                    visible: true
                  }),
                  beforeSend: function(xhr) {
                    $(".table label:not(:disabled)").addClass("disabled");
                    $(".table button:not(:disabled)").addClass("disabled");
                  }
              }).done(function(data) {
                if (self.method === "POST" || input.hasClass("restore-ignored")) {
                  $(".table tbody tr").fadeOut(250).promise().done(function() {
                    $(this).remove();
                    $(".table tbody").append("<tr><td colspan=\"12\">" + self.spinner + "</td></tr>");
                    location.reload();
                  });
                } else {
                  $(".table button").removeClass("disabled");
                  $("label").each(function() {
                      var is_active = $(this).hasClass("active");
                      $(this).removeClass("active").removeClass("disabled");
                      if($("input:first-child:not(:disabled)", this).attr("data-action") === action) {
                        $(this).addClass("active");
                      }
                      if($("input:first-child", this).prop("disabled")) {
                        $(this).addClass("disabled");
                        if (is_active) {
                          $(this).addClass("active");
                        }
                      }
                  });
                }
              });
          } else {
              var occurrence_id = $(this).attr("data-occurrence-id");
              $.ajax({
                  method: self.method,
                  url: self.path + "/user-occurrence/" + occurrence_id + ".json",
                  dataType: "json",
                  data: JSON.stringify({
                    user_id: self.user_id,
                    action: action,
                    visible: true
                  }),
                  beforeSend: function(xhr) {
                    $("label", row).addClass("disabled");
                    $("button", row).addClass("disabled");
                  }
              }).done(function(data) {
                if(self.method === "POST" || input.hasClass("restore-ignored")) {
                  input.parents("tr").fadeOut(250).promise().done(function() {
                    $(this).remove();
                    if ($("input.action-radio").length <= 6) {
                      $(".table tbody").append("<tr><td colspan=\"12\">" + self.spinner + "</td></tr>");
                      location.reload();
                    }
                  });
                } else {
                  $("label", row).removeClass("active").removeClass("disabled");
                  label.addClass("active");
                  $("button", row).removeClass("disabled");
                }
              });
          }
          return false;
      });

      $("button.remove:not(:disabled)").on("click", function() {
        var occurrence_id = $(this).attr("data-occurrence-id"),
            row = $(this).parents("tr");
        $.ajax({
            method: "DELETE",
            url: self.path + "/user-occurrence/" + occurrence_id + ".json",
            data: JSON.stringify({ user_id: self.user_id }),
            beforeSend: function(xhr) {
              $("label", row).addClass("disabled");
              $("button", row).addClass("disabled");
            }
        }).done(function(data) {
          row.fadeOut(250, function() {
            row.remove();
            if ($("button.remove:not(:disabled)").length === 0) {
              location.reload();
            }
          });
        });
        return false;
      });

      $("button.remove-all").on("click", function() {
        var occurrence_ids = $.map($("[data-occurrence-id]:not(:disabled)"), function(e) {
              return $(e).attr("data-occurrence-id");
            }).all_unique().toString();
        if(!occurrence_ids.trim()) {
          return false;
        }
        $.ajax({
            method: "DELETE",
            url: self.path + "/user-occurrence/bulk.json",
            dataType: "json",
            data: JSON.stringify({
              user_id: self.user_id,
              occurrence_ids: occurrence_ids
            }),
            beforeSend: function(xhr) {
              $(".table label").addClass("disabled");
              $(".table button").addClass("disabled");
            }
        }).done(function(data) {
          $(".table tbody tr").fadeOut(250).promise().done(function() {
            $(this).remove();
            $(".table tbody").append("<tr><td colspan=\"12\">" + self.spinner + "</td></tr>");
            location.reload();
          });
        });
        return false;
      });

      $("button.hide-all").on("click", function() {
        var occurrence_ids = $.map($("[data-occurrence-id]:not(:disabled)"), function(e) {
              return $(e).attr("data-occurrence-id");
            }).all_unique().toString();
        if(!occurrence_ids.trim()) {
          return false;
        }
        $.ajax({
            method: self.method,
            url: self.path + "/user-occurrence/bulk.json",
            dataType: "json",
            data: JSON.stringify({
              user_id: self.user_id,
              occurrence_ids: occurrence_ids,
              visible: 0
            }),
            beforeSend: function(xhr) {
              $(".table label").addClass("disabled");
              $(".table button").addClass("disabled");
            }
        }).done(function(data) {
          $(".table tbody tr").fadeOut(250).promise().done(function() {
            $(this).remove();
            $(".table tbody").append("<tr><td colspan=\"12\">" + self.spinner + "</td></tr>");
            location.reload();
          });
        });
        return false;
      });

      $("button.hide:not(:disabled)").on("click", function() {
        var occurrence_id = $(this).attr("data-occurrence-id"),
            row = $(this).parents("tr");
        $.ajax({
            method: self.method,
            url: self.path + "/user-occurrence/" + occurrence_id + ".json",
            dataType: "json",
            data: JSON.stringify({ user_id: self.user_id, visible: 0 }),
            beforeSend: function(xhr) {
              $("label", row).addClass("disabled");
              $("button", row).addClass("disabled");
            }
        }).done(function(data) {
          row.fadeOut(250, function() {
            row.remove();
            if ($("button.hide:not(:disabled)").length === 0) {
              location.reload();
            }
          });
        });
        return false;
      });

      $("button.thanks").on("click", function(e) {
        e.stopPropagation();

        var button = this,
            recipient_identifier = $(this).attr("data-recipient-identifier");
        $.ajax({
          method: "POST",
          url: self.path + "/message.json",
          dataType: "json",
          data: JSON.stringify({
            recipient_identifier: recipient_identifier
          })
        }).done(function(data) {
          $(button).removeClass("btn-outline-danger")
                   .addClass("btn-outline-success")
                   .addClass("disabled")
                   .prop("disabled", true)
                   .find("i").removeClass("fa-heart").addClass("fa-check");
        });
      });
    },

    activate_refresh: function(){
      var self = this;

      $("a.profile-flush").on("click", function(e) {
        var link = $(this);

        e.stopPropagation();
        e.preventDefault();
        $.ajax({
            method: "GET",
            url: $(this).attr("href"),
            beforeSend: function(xhr) {
              link.addClass("disabled").find("i").first().addClass("fa-spin");
            }
        }).done(function(data) {
          link.find("i").first().removeClass("fa-spin");
          $("#flush-message").alert().show();
          $("#flush-message").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });

      $("a.organization-refresh").on("click", function(e) {
        var button = $(this);

        e.stopPropagation();
        e.preventDefault();
        $.ajax({
            method: "GET",
            url: button.attr("href"),
            beforeSend: function(xhr) {
              button.addClass("disabled").find("i").first().addClass("fa-spin");
            }
        }).done(function(data) {
          button.find("i").first().removeClass("fa-spin");
          $(".alert").alert().show();
          $(".alert").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });

      $("a.dataset-refresh").on("click", function(e) {
        var button = $(this);

        e.stopPropagation();
        e.preventDefault();
        $.ajax({
            method: "GET",
            url: button.attr("href"),
            beforeSend: function(xhr) {
              button.addClass("disabled").find("i").first().addClass("fa-spin");
            }
        }).done(function(data) {
          button.find("i").first().removeClass("fa-spin");
          $(".alert-gbif").alert().show();
          $(".alert").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });

      $("a.dataset-frictionless").on("click", function(e) {
        var button = $(this);

        e.stopPropagation();
        e.preventDefault();
        $.ajax({
            method: "GET",
            url: button.attr("href"),
            beforeSend: function(xhr) {
              button.addClass("disabled").find("i").first().addClass("fa-spin");
            }
        }).done(function(data) {
          button.find("i").first().removeClass("fa-spin");
          $(".alert-frictionless").alert().show();
          $(".alert").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });

      $("#articles-check").on("click", function(e) {
        var button = $(this);

        e.stopPropagation();
        e.preventDefault();
        $.ajax({
            method: "GET",
            url: button.attr("href"),
            beforeSend: function(xhr) {
              button.addClass("disabled").find("i").first().addClass("fa-spin");
            }
        }).done(function(data) {
          location.reload();
        });
        return false;
      });

      $("a.article-process").on("click", function(e) {
        var button = $(this);

        e.stopPropagation();
        e.preventDefault();
        $.ajax({
            method: "GET",
            url: button.attr("href"),
            beforeSend: function(xhr) {
              button.addClass("disabled").find("i").first().addClass("fa-spin");
            }
        }).done(function(data) {
          button.find("i").first().removeClass("fa-spin");
          $(".alert-article-process").alert().show();
          $(".alert").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });

      $("a.taxon-process").on("click", function(e) {
        var button = $(this);

        e.stopPropagation();
        e.preventDefault();
        $.ajax({
            method: "GET",
            url: button.attr("href"),
            beforeSend: function(xhr) {
              button.addClass("disabled").find("i").first().addClass("fa-spin");
            }
        }).done(function(data) {
          button.find("i").first().removeClass("fa-spin");
          if (data == null) {
            $('#taxon-search-result').html("No image found.");
            $(".alert-taxon-process").removeClass("alert-success").addClass("alert-warning");
          }
          $(".alert-taxon-process").alert().show();
          $(".alert").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });

      $("a.help-refresh").on("click", function(e) {
        e.stopPropagation();
        e.preventDefault();
        location.reload();
      });

    },

    activate_popovers: function() {
      var self = this;
      $.each($('[data-toggle="popover"]'), function(index, value) {
        var _self = this;
        $(this).popover({
          container: $(_self),
          trigger: 'hover',
          html: true,
          content: function() { return self.gbif_images($(_self)); }
        }).on('hide.bs.popover', function() {
          if($('.popover:hover', _self).length) {
            return false;
          }
        });
      });
    },

    gbif_images: function(obj) {
      var self = this;
      $.ajax({
        url: "/occurrence/" + $(obj).attr("data-gbifid") + "/still_images.json",
        method: "GET",
        dataType: "json",
      }).done(function(data) {
        $(obj).find('.popover-body')
              .html(self.carousel_template(data, $(obj).attr("data-gbifid")))
              .find("img").each(function() {
                var item = $(this);
                self.wait_loader(item[0]).then(()=>{
                  if(item[0].naturalHeight > 300) {
                    item.mlens({
                      imgSrc:item.attr("data-big"),
                      lensShape:"square",
                      lensSize: ["100px","100px"],
                      borderSize:0,
                      zoomLevel: 1
                    });
                  }
                });
              });
      });
      return self.spinner;
    },

    wait_loader: function(img) {
      return new Promise(resolve => { img.onload = resolve; });
    },

    carousel_template: function(data, id) {
      var html  = "";
      html += '<div id="carousel-indicators-'+id+'" class="carousel slide" data-ride="carousel" style="min-width:250px;min-height:100px;">';
      if (data.length > 1) {
        html += '<ol class="carousel-indicators">';
        $.each(data, function(index, value) {
          var active = (index === 0) ? " class='active'" : "";
          html += '<li data-target="#carousel-indicators-'+id+'" data-slide-to="'+index+'"'+active+'></li>';
        });
        html += '</ol>';
      }
      html += '<div class="carousel-inner">';
      $.each(data, function(index, value) {
        var active = (index === 0) ? " active" : "";
        html += '<div class="carousel-item'+active+'">';
        html += '<a href="'+value.original+'" target="_blank"><img src="'+ value.small +'" class="d-block" data-big="'+value.large+'"/></a>';
        html += '</div>';
      });
      html += '</div>';
      if (data.length > 1) {
        html += '<a class="carousel-control-prev" href="#carousel-indicators-'+id+'" role="button" data-slide="prev">';
        html += '<span class="carousel-control-prev-icon" aria-hidden="true"></span>';
        html += '<span class="sr-only">Previous</span>';
        html += '</a>';
        html += '<a class="carousel-control-next" href="#carousel-indicators-'+id+'" role="button" data-slide="next">';
        html += '<span class="carousel-control-next-icon" aria-hidden="true"></span>';
        html += '<span class="sr-only">Next</span>';
        html += '</a>';
      }
      html += '</div>';
      return html;
    },

    candidate_counter: function() {
      var self = this, slug = "";
      if (self.path === "/profile") {
        slug = self.path;
      } else if (self.path === "/admin" && self.identifier) {
        slug = self.path + "/user/" + self.identifier;
      } else if (self.path === "/help-others" && self.identifier) {
        slug = self.path + "/" + self.identifier;
      }
      if (slug.length > 0 && $("#specimen-counter").length) {
        $.ajax({
          method: "GET",
          url: slug + "/candidate-count.json"
        }).done(function(data) {
          if (data.count > 0 && data.count <= 50) {
            $("#specimen-counter").text(data.count).show();
          } else if (data.count > 50) {
            $("#specimen-counter").text("50+").show();
          }
        });
      }
    },

    helper_navbar: function() {
      var self = this;
      if ($('#helper-info').length && $('#helper-navbar').length) {
        if (self.path === "/help-others" || self.path === "/admin") {
          var navbar = $('#helper-navbar');
          $(document).scroll(function() {
            if ($(this).scrollTop() > $('#helper-info').offset().top) {
              navbar.removeClass('d-none');
            } else {
              navbar.addClass('d-none');
            }
          });
        }
      }
    },

    helper_modal: function() {
      var self = this, helper_list = "";
      $('#helperPublicModal').on('show.bs.modal', function (event) {
        var helpers_list = $("#helpers-list").hide().next();
        $("#helpers-list-none").hide();
        helpers_list.empty();
        $('#visibility-form').preventDoubleSubmission().submit(function() {
          $(this).find("button[type='submit']").prop('disabled',true);
        });
        $.ajax({
          method: "GET",
          url: "/help-others/" + self.identifier + "/helpers.json"
        }).done(function(data) {
          if (data.helpers.length > 0) {
            helper_list = $.map(data.helpers, function(i) {
              var email = "";
              if (i.email && i.email.length > 0) {
                email = " (" + i.email + ")";
              }
              return "<li>" + i.given + " " + i.family + email + "</li>";
            });
            helpers_list.append(helper_list.join("")).prev().show();
          } else {
            $("#helpers-list-none").show();
          }
        });
      });
    }
  };

  return {
    init: function(user_id, method, path, identifier) {
      _private.init(user_id, method, path, identifier);
    }
  };

}(jQuery, window));
