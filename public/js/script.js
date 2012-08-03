(function(jQuery, window, undefined){

if ($("body").hasClass("fridge")){

var latest_scratch = 0, latest_notification = 0,
	kLINK_DETECTION_REGEX = /\b((?:[a-z][\w-]+:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))/gi;
function fetch_home(){
	twitter();
	$.getJSON("/home.json", function(data){
		$(".relativeTime").each(function(){
			$(this).html($.relativeTime($(this).data("date")));
		});
		var users = data[0],
			scratches = data[1],
			notifications = data[2],
			current_user = data[3],
			uhtml = "";
		$(users).each(function(i,el){
			if (el.logged_in){
				if (el.id == current_user.id){
					uhtml += '<div class="current_user user clearfix" href="#">';
				} else {
					uhtml += '<div class="user clearfix">';
				}
				uhtml += '<div class="avatar" style="background:url('+el.avatar_url+') center; background-size:cover;"></div><div class="meta">';
				uhtml += '<p class="username"><a>'+el.username+'</a></p>';
				uhtml += '<p class="nickname">"'+el.nickname+'\"</p>';
				uhtml += '<p class="focus">Focus: '+ replaceLinks(el.focus)+'</p>';
				uhtml += '<p class="location">Location: '+ replaceLinks(el.location) +'</p>';
				uhtml += '<p class="email"><a target="_blank" href="mailto:'+el.email+'">Email</a></p>';
				uhtml += '</div></div>';
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
				if (el.mtext.indexOf("#focus") >= 0){
					shtml += '<div class="scratch focus clearfix" data-index="' + el.id + '">';
				} else if (el.mtext.indexOf("#location") >= 0){
					shtml += '<div class="scratch location clearfix" data-index="' + el.id + '">';
				} else {
					shtml += '<div class="scratch clearfix" data-index="' + el.id + '">';
				}
				shtml += "<div class='clearfix'>";
				shtml += '<span class="posted_by floatleft"><img src="'+user.avatar_url+'"><br><b>' + user.username + '</b></span>';
				shtml += '<div class="floatleft scratch_content">';
				shtml += '<div class="mtext">'+ replaceLinks(el.mtext) + '</div>';
				shtml += '<p class="boomcount" id="boomcount-for-'+el.id+'">' + el.boomcount + " Booms</p>";
				shtml += '<form class="boom_form" action="/scratch/' + el.id + '/boom" method="post"><input type="submit" value="BOOM!"></form>';
				shtml += (el.clly) ? el.clly : "";
				shtml += (el.jsfiddle) ? el.jsfiddle : "";
				shtml += '<br><small><i class="relativeTime" data-date="'+el.created_at+'">'+$.relativeTime(el.created_at)+'</i></small></div></div>';
				shtml += '<h5>Thoughts:</h5><div class="thoughts clearfix" id="thoughts-for-'+ el.id +'">';
				shtml += '</div>'
				shtml += '<a href="#" class="thought_link">Post a thought</a>';
				shtml += '<form class="thought_form" action="/scratches/' + el.id + '/thoughts" method="POST">';
				shtml += '<textarea name="mtext">A thought...</textarea>';
				shtml += '<input type="submit" value="post">';
				shtml += '</form>';
				shtml += '</div>';
			}
		});
		if ($("#scratches").html() != shtml){
			$("#scratches").prepend(shtml);
			latest_scratch = parseInt($(".scratch").eq(0).data("index"));
		}
		getThoughts();
		getBooms();
		var nhtml = "";
		$(notifications).each(function(i,el){
			if (!el.read){
				var from = el.creator;
				nhtml += '<div class="notification clearfix" data-index="'+ el.id +'"><p>From <b>' + from.username + '</b></p>';
				nhtml += '<p class="notification_message">' + replaceLinks(el.mtext) + '</p>';
				nhtml += '<form action="/notifications/'+el.id+'/read" method="POST"><input type="submit" value="clear"></form>';
				nhtml += "</div>";
			}
		});
		if (nhtml == ""){
			nhtml = "<i>no notifications at this time.</i>";
		}
		if ($("#notifications").html() != nhtml || $("#notifications").html() == ""){
			$("#notifications").html(nhtml);
		}
		if (notifications.length > 0){
			document.title = "(" + notifications.length + ")" + " The Fridge";
		} else {
			document.title = "The Fridge";
		}
	});
}
fetch_home();

$("#rightbar, #leftbar, #scratchboard").on("submit", "form", function(e){
	e.preventDefault();
	var f = $(this);
	if (f.hasClass("boom_form")){
				var curbc = parseInt(f.siblings(".boomcount").html().split(" ")[0]);
				curbc++;
				f.siblings(".boomcount").html(curbc + " Booms");
			}
	$.post(f.attr("action"), f.serialize(), function(data){
		console.log(data);
		if (data.status == "success"){
			fetch_home();
			f.find("textarea").val("Success!");
			f.removeClass('submitting');
		} else if (data.status == "failure" || data == undefined) {
			f.find("textarea").val("Failure... try again.");
		}
	});
}).on("focus", "textarea", function(){
	var originalval = $(this).val();
	$(this).val("");
	$(this).on("blur", function(){
		if ($(this).val() == ""){
			$(".autocomplete").remove();
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
	$(this).off("keydown");
});


$("#scratchboard").on("click", ".posted_by", function(e){
	e.preventDefault();
	var username = $(this).find("b").text();
	$(window).scrollTop(0);
	$("#scratchboard form textarea").focus().val("@"+username+" ");
}).on("click", "img", function(){
	$('<div class="overlay"></div><div class="overlay_content" style="background-image: url('+$(this).attr("src")+');"><div class="close_overlay">X</div>').appendTo("body");
});
$(document).on("click", ".user", function(e){
	if ($(e.target).html() != "Email"){
		e.preventDefault();
		$(window).scrollTop(0);
		var a = $(this).find("a").first();
		$("#scratchboard form").first().find("textarea").blur().focus().val("@" + a.html() + " ");
	}
}).on("click", ".close_overlay, .overlay", function(){
	$(".overlay, .overlay_content, .close_overlay").fadeOut(function(){
		$(".overlay, .overlay_content, .close_overlay").remove();
	})
})


function twitter(){
	var t = ["taylorleejones", "jcutrell", "whiteboardis", "ericbrwn", "taylordolan", "department85", "benjaminfleet"],
		twittersearchurl = t.join("+OR+from:");

	$.getJSON("http://search.twitter.com/search.json?q=from:"+twittersearchurl+"&rpp=10&callback=?", buildtweets);
}


function buildtweets(data){
	var h = "";
	$(data.results).each(function(i,el){
		h += '<div class="tweet"><a class="from_user" href="http://twitter.com/'+el.from_user+'">'+el.from_user+"</a>";
		h += '<p class="tweettext">'+ replaceLinks(el.text) +"</p>";
		h += '<small class="relativeTime" data-date="'+el.created_at+'">'+$.relativeTime(el.created_at)+'</small>';
		h += "</div>";
	});
	if ($("#twitter").html() != h){
		$("#twitter").html(h);
	}
}
$("#scratchboard h4 span").on("click", function(){
	$("#scratchboard textarea").first().blur().focus();
	var curval = $("#scratchboard textarea").val()
	$("#scratchboard textarea").val($(this).text() + " " + curval);
});

function getusername(users,id){
	var user = $(users).filter(function(i,el){
		return el.id == id;
	})[0];
	return user.username;
}
function getThoughts(){
	var ids = [];
	$(".scratch").each(function(){
		ids.push($(this).data("index"))
	});
	$.getJSON("/thoughts/" + ids.join(","), function(data){
		var thtml = {};
		$(data).each(function(i,el){
			if (!thtml[el.scratch_id]){
				thtml[el.scratch_id] = "";
			}
			thtml[el.scratch_id] += '<div class="thought clearfix">';
			thtml[el.scratch_id] += '<p class="thought_by">' + el.user.username + "</p>";
			thtml[el.scratch_id] += '<p class="thought_text">' + replaceLinks(el.mtext);
			if (el.created_at){
				 thtml[el.scratch_id] += '<span class="relativeTime floatright" data-date="'+el.created_at+'">'+$.relativeTime(el.created_at)+'</span>';
			}
			thtml[el.scratch_id] += "</p></div>";
		});
		for (h in thtml){
			if ($("#thoughts-for-" + h).html() != thtml[h]){
				$("#thoughts-for-" + h).html(thtml[h]);
			}
		}
	});
}
function getBooms(){
	var ids = [];
	$(".scratch").each(function(){
		ids.push($(this).data("index"))
	});
	$.getJSON("/booms/" + ids.join(","), function(data){
		$(data).each(function(i,el){
			if ($("#boomcount-for-" + el.id).html() != el.boomcount + " Booms"){
				$("#boomcount-for-" + el.id).html(el.boomcount + " Booms");
			}
		});
	});
}
$("#scratchboard").on("click", ".thought_link", function(e){
	e.preventDefault();
	$(this).hide().siblings("form").show().find("textarea").focus();
});

setTimeout(function(){
	$(".flash").slideUp(function(){$(".flash").remove()});
}, 3000);

$(document).on("keydown", function(e){
	if ($(e.target).parents("form").length){
		return;
	}
	if (e.keyCode == 83 ){
		e.preventDefault();
		$("#scratchboard form").first().find("textarea").blur().focus();
	} else if (e.keyCode == 70){
		e.preventDefault();
		$("#scratchboard form").first().find("textarea").blur().focus().val("#focus: ");
	} else if (e.keyCode == 76){
		e.preventDefault();
		$("#scratchboard form").first().find("textarea").blur().focus().val("#location: ");
	}
}).on("keyup", function(e){
	if ($(e.target).val().indexOf("@") >= 0){
		setTimeout(function(){
			autoComplete($(e.target).val());
		}, 300);
	} else {
		$(".autocomplete").remove();
	}
});

function autoComplete(value){
	// to do: autocomplete
	var html = "";
	value = $.trim(value.replace("@", ""));
	$.getJSON("/usernames.json", {val : value}, function(data){
		if (data.length > 0){
			html += '<ul class="autocomplete">';
			$(data).each(function(i,u){
				html += "<li>" + u.username + "</li>";
			});
			html += "</ul>";
		}
		if (html != ""){
			$("#scratchboard").find("ul.autocomplete").remove().end().find("form").first().find("textarea").after(html);
			$(".autocomplete").on("click", "li", function(){
				$("#scratchboard form").first().find("textarea").blur().focus().val("@" + $(this).html() + " ");
				$(this).parents("ul").remove();
			})
		} else {
			$(".autocomplete").off("click");
		}
	});
	return;
}
function replaceLinks(s){
	if (s){
		if (!(s.indexOf("iframe") >= 0) && !(s.indexOf("<a") >= 0)){
			return s.replace(kLINK_DETECTION_REGEX, '<a href="$1" target="_blank">$1</a>');
		} else {
			return s;
		}
	}
}

$("#rightbar").on("mouseenter", function(e){
	$(this).toggleClass("open");
});
$("body").on("click", "a.tldr", function(){
	$(this).siblings(".tldr").toggle(200);
});

setInterval(fetch_home, 3000);

} // ending body check
}($, window));