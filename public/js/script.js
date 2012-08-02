var latest_scratch = 0, latest_notification = 0;
function fetch_home(){
	twitter();
	$.getJSON("/home.json", function(data){
		var users = data[0],
			scratches = data[1],
			notifications = data[2],
			current_user = data[3],
			uhtml = "";
		$(users).each(function(i,el){
			if (el.logged_in){
				if (el.id == current_user.id){
					uhtml += '<a class="current_user user clearfix" href="mailto:'+el.email+'">';
				} else {
					uhtml += '<a class="user clearfix" href="mailto:'+el.email+'">';
				}
				uhtml += '<div class="avatar" style="background:url('+el.avatar_url+') center; background-size:cover;"></div><div class="meta">';
				uhtml += '<p class="username">'+el.username+'</p>';
				uhtml += '<p class="nickname">"'+el.nickname+'\"</p>';
				uhtml += '<p class="focus">Focus: '+el.focus+'</p>';
				uhtml += '<p class="location">Location: '+el.location+'</p>';
				uhtml += '</div></a>';
			}
		});
		if ($("#users").html() != uhtml){
			$("#users").html(uhtml);
		}
		if ($("#focus").html() != current_user.focus){
			$("#focus").html(current_user.focus);
		}

		var shtml = "";
		$(scratches).each(function(i,el){
			if (el.id > latest_scratch) {
				var user = $(users).filter(function(i){
					return this.id == el.user_id;
				})[0];
				shtml += '<div class="scratch clearfix" data-index="' + el.id + '">';
				shtml += '<span class="posted_by floatleft"><img src="'+user.avatar_url+'"><br><b>' + user.username + '</b></span>';
				shtml += '<p>'+el.mtext+ '</p><br><small><i>'+$.relativeTime(el.created_at)+'</i></small>';
				shtml += (el.clly) ? el.clly : "";
				shtml += (el.jsfiddle) ? el.jsfiddle : "";
				shtml += '</div>';
			}
		});
		if ($("#scratches").html() != shtml){
			$("#scratches").prepend(shtml);
			latest_scratch = parseInt($(".scratch").eq(0).data("index"));
		}
		var nhtml = "";
		$(notifications).each(function(i,el){
			if (!el.read){
				var from = el.creator;
				nhtml += '<div class="notification clearfix" data-index="'+ el.id +'"><p>From <b>' + from.username + '</b></p>';
				nhtml += '<p class="notification_message">' + el.mtext + "</p>";
				nhtml += '<form action="/notifications/'+el.id+'/read" method="POST"><input type="submit" value="clear"></form>';
				nhtml += "</div>";
			}
		});
		if (nhtml == ""){
			nhtml = "<i>no notifications at this time.</i>";
		}
		if ($("#notifications").html() != nhtml || $("#notifications").html() == ""){
			console.log(nhtml);
			$("#notifications").html(nhtml);
		}
	});
}
fetch_home();

$("#rightbar, #leftbar, #scratchboard").on("submit", "form", function(e){
	e.preventDefault();
	var f = $(this);
	$.post(f.attr("action"), f.serialize(), function(data){
		if (data.status == "success"){
			fetch_home();
			f.find("textarea").val("Success!");
			f.removeClass('submitting');
		} else if (data.status == "failure") {
			f.find("textarea").val("Failure... try again.");
		}
	});
}).find("textarea").on("focus", function(){
	var originalval = $(this).val();
	$(this).val("");
	$(this).on("blur", function(){
		if ($(this).val() == ""){
			$(this).val(originalval);
		}
	});
});



$("body").on("focus", "textarea", function(){
	$(this).on("keydown", function(e){
		if (e.keyCode == 13){
			e.preventDefault();
			$(this).trigger("blur").parents("form").addClass("submitting").submit();
		}
	});
}).on("blur", "textarea", function(){
	$(this).off("keyup");
});


$("#scratchboard").on("click", ".posted_by", function(e){
	e.preventDefault();
	var username = $(this).find("b").text();
	$(window).scrollTop(0);
	$("#scratchboard form textarea").focus().val("@"+username+" ");
});


function twitter(){
	var t = ["taylorleejones", "jcutrell", "whiteboardis", "ericbrwn", "taylordolan", "department85", "benjaminfleet"],
		twittersearchurl = t.join("+OR+from:");

	$.getJSON("http://search.twitter.com/search.json?q=from:"+twittersearchurl+"&rpp=10&callback=?", buildtweets);
}


function buildtweets(data){
	var h = "";
	$(data.results).each(function(i,el){
		h += '<div class="tweet"><a class="from_user" href="http://twitter.com/'+el.from_user+'">'+el.from_user+"</a>";
		h += '<p class="tweettext">'+el.text+"</p>";
		h += '<small>'+$.relativeTime(el.created_at)+'</small>';
		h += "</div>";
	});
	if ($("#twitter").html() != h){
		$("#twitter").html(h);
	}
}








setInterval(fetch_home, 3000);
