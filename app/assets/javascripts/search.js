$(function() {
  zone_one_search.setup_bulk_actions();
  zone_one_search.setup_per_page_refresh();
});


var zone_one_search = {
  setup_per_page_refresh: function () {
    $("#refresh-per-page").live("click", function () {
      $("#per_page").val($("#per_page_user_input").val());
      $("#execute_search_image").click();
    });
  },
  setup_bulk_actions: function () { 
    $('#download-submit, #bulk-edit-submit').click(function() {
      zone_one_search.clone_downloadable_checkboxes_to($(this).parent());
      $(this).parent().submit();
      return false;
    });

    $('#bulk-delete-submit').click(function() {
      var bulk_delete = $('#bulk-delete');
      $(bulk_delete).children('input').remove();
      zone_one_search.clone_downloadable_checkboxes_to(bulk_delete);
      var count = $(bulk_delete).children("input:checked").length;
      $(bulk_delete).append($('<input>').attr('type', 'hidden').attr('name', 'previous_search').val(location.href));
      $('<p>').html("Are you sure you want to delete the " + count + " items?").dialog({
        buttons: [
          {
            text: "Yes",
            click: function() { 
              $(this).dialog('close');
              $(bulk_delete).submit();
              return true;
            }	
          },
          {
            text: "No",
            click: function() { $(this).dialog('close'); }	
          }
        ]
      });
      return false;
    });
                          
    // Use change instead of click for more robust handling of
    // check/uncheck by javascript
    $("#bulk_select").live("change", function () {

      // checked = true, unchecked = undefined
      var checked_state = $("#bulk_select").attr("checked");

      if(checked_state) { 

        // loop and check
        $("input.downloadable[type='checkbox']").each( function(index) {
          $(this).attr('checked', true);
        });

        $("#offer-select-all").show(); 
      } else {

        //loop and uncheck
        $("input.downloadable[type='checkbox']").each( function(index) {
          $(this).attr('checked', false);
        });
      
        //loop and uncheck other pages as well
        $("input.downloadable-other-pages[type='checkbox']").each( function(index) {
          $(this).attr('checked', false);
        });
        $("#offer-clear-selection").hide();
        $("#offer-select-all").hide();
      } 
    });

    $("#select-all-results").live("click", function () {
      $("input.downloadable-other-pages[type='checkbox']").each( function(index) {
        $(this).attr('checked', true);
      });
      $("#offer-select-all").hide();
      $("#offer-clear-selection").show();
    });

    $("#clear-select-all-results").live("click", function () {
     $("#offer-clear-selection").hide();
     
     // Fires the change function above
     $("#bulk_select").click(); 
    });
  },
	clone_downloadable_checkboxes_to: function(destination) {
		destination.children("input:checked").remove();
		destination.append($('.downloadable:checked').clone());
    destination.append($('.downloadable-other-pages:checked').clone());
		destination.children("input:checked").hide();
	}
}
