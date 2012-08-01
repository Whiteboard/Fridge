function fetch_home(){
	$.getJSON("/home.json", function(data){
		var users = data[0];
		var scratches = data[1];
		var uhtml = "";
		$(users).each(function(i,el){
			if (el.logged_in){
				uhtml += '<a class="user" href="mailto:'+el.email+'">';
				uhtml += '<div class="avatar"><img src="'+el.avatar_url+'"></div>';
				uhtml += '<p class="username">'+el.username+'</p>';
				uhtml += '<p class="nickname">"'+el.nickname+'\"</p>';
				uhtml += '<p class="status">Status: '+el.status+'</p>';
				uhtml += '<p class="location">Location: '+el.location+'</p>';
				uhtml += '</a>';
			}
		});
		if ($("#users").html() != uhtml){
			$("#users").html(uhtml);
		}
		var html = "";
		$(scratches).each(function(i,el){
			var user = $(users).filter(function(i){
				return this.id == el.user_id;
			})[0];
			html += '<div class="scratch">';
			html += '<p>'+el.mtext+ '<span class="posted_by floatright">' + user.username + '</span>' + '</p>';
			html += (el.clly) ? el.clly : "";
			html += (el.jsfiddle) ? el.jsfiddle : "";
			html += '</div>';
		});
		if ($("#scratches").html() != html){
			$("#scratches").html(html);
		}
	});
}
fetch_home();

$("#forms form").on("submit", function(e){
	e.preventDefault();
	var f = $(this);
	$.post(f.attr("action"), f.serialize(), function(data){
		if (data.status == "success"){
			console.log(this);
			f.find("textarea").val("Success!");
			fetch_home();
		} else if (data.status == "failure") {
			f.find("textarea").val("Failure... try again.");
		}
	});
}).find("textarea").on("focus", function(){
	var originalval = $(this).val();
	$(this).val("");
	$(this).on("blur", function(){
		$(this).val(originalval);
	});
})

setInterval(fetch_home, 3000);

// $("form").on("submit", function(e){
// 	e.preventDefault();
// 	console.log(e);
// 	$.post($(this).attr("action"), $(this).serialize(), function(res){
// 		console.log(res);
// 	})
// })