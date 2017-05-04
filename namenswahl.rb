# -*- encoding : utf-8 -*-
#!/bin/env ruby
require 'sinatra'
require 'dm-core'
require 'dm-timestamps'
require 'dm-validations'
require 'dm-migrations'
require 'dm-constraints'
require 'dm-serializer'
require 'digest/sha2'
require "chartkick"

 @@datenbank_datei = "#{Dir.pwd}/namen.db"

helpers do
	def erstelle_namen(vorname, middlename)
		begin
			Namen.create(:vorname => vorname , :middlename => middlename)
		rescue
			# puts "Der Name ist nicht erstellt worden. (Db Error)"
		end
	end

	def schaue_ob_namen_existieren(vorname, middlename)
		this = Namen.first(:vorname => vorname, :middlename => middlename) || false
	end

	def delete_by_id(id)
		this = Namen.first(:id => id )
		this.destroy
	end

	def find_database_object_by_id(id)
		Namen.first(:id => id) || false
	end

	def add_vote_for_name_by_id(id)
		obj = find_database_object_by_id(id)
		vote = obj[:votes] + 1
		obj.update(:votes => vote)
	end

	def string_validation(string)
		#Der String darf Buchstaben enthalten.
		#Die Länge des Strings darf min 3, max 13 chars betragen.
		if string =~ /(^[a-zA-Z]{3,13})$/
			return true
		else
			return false
		end
	end

  def get_hash_for_chart
  	namen = Namen.all
		hash = Hash.new
		namen.each do |n|
			hash[n['vorname'] + " " + n['middlename']] = n.votes
		end
		hash || false
  end

  def store_ip_in_db
  	ip = @env['REMOTE_ADDR']
  	Votesecure.create(:ip => ip, :datum => Time.now) || false
  end

  def is_ip_in_db
  	ip = @env['REMOTE_ADDR']
  	Votesecure.last(:ip => ip) || false
  end

  def when_did_ip_vote
  	ip = @env['REMOTE_ADDR']
  	obj = Votesecure.last(:ip => ip) || false
  	if obj
  		return obj[:datum]
  	else
  		return false
  	end
  end

  def last_vote_of_ip
  	#Hiermit prüfe ich wieviel Zeit vergangen ist, seit der letzten Useraktion/ip
  	ip = @env['REMOTE_ADDR']
  	obj = Votesecure.last(:ip => ip) || false
  	if obj
	  	# puts obj
	    time = Time.now
	    # puts time.tttleto_time
	    ipdatum = obj['datum'].to_time+(2*60*60) || false #stunden * minuten * sekunden
	    # puts ipdatum
	    if ipdatum > time
	    	return true
	    else
	    	return false
	    end
 	 end
  end

	def get_all_vote_counts
	#zähle alle werte der spalte votes zusammen und gib die zahl aus
		this = Namen.all
		votes = 0
		this.each do |obj|
			votes += obj[:votes]
		end
		votes
	end
end

before do
	@header = "Looking for a name"
end

class Namen
	include DataMapper::Resource
	property :id, Serial
	property :vorname, String
	property :middlename, String
	property :votes, Integer,:default  => 0
end

class Votesecure
	include DataMapper::Resource
	property :id, Serial
	property :ip, String, :length => 15
	property :datum, DateTime
end

DataMapper.setup :default, "sqlite://#{Dir.pwd}/namen.db"
DataMapper.finalize
#DataMapper.auto_migrate!
DataMapper.auto_upgrade!

get '/' do
	@hash =
	@subheader = 'Willkommen auf der Namevote Seite von Sandra & Marco.'
	@erklaerung = 'Hier kannst du uns helfen einen coolen Namen für unser Kind zu finden.:'
	erb :home
end

get '/voten_hinweis' do
	@subheader = 'Warnhinweis zum Votingsystem'
	@erklaerung = 'Zu oft gevotet - Manipulationsversuch:'
	erb :voten_hinweis
end


get '/neuer_name' do
	@subheader = 'Namensvorschlag'
	@erklaerung = 'Bitte schlage einen Vor- und Zweitnamen vor:'
	erb :neuer_name
end

post '/neuer_name' do
	if string_validation(params[:vorname]) && string_validation(params[:middlename]) && !last_vote_of_ip
	 	 if schaue_ob_namen_existieren(params[:vorname], params[:middlename])
			  redirect '/'
	 	else
				erstelle_namen(params[:vorname], params[:middlename])
				store_ip_in_db
				redirect '/zeige_namen'
		end
	else
		redirect '/voten_hinweis'
	end
end

get '/admin/delete/:id' do
	delete_by_id(params[:id])
end

get '/abstimmen/:id' do
	if is_ip_in_db
		if !last_vote_of_ip
			add_vote_for_name_by_id(params[:id])
			store_ip_in_db
		else
			redirect '/voten_hinweis'
		end
	else
		add_vote_for_name_by_id(params[:id])
		store_ip_in_db
	end
			# add_vote_for_name_by_id(params[:id])

	redirect '/zeige_namen'
end

get '/zeige_namen' do
	@subheader = 'Alle eingegangenen Namen:'
	@erklaerung = 'Hier können Sie für einen Namen voten:'
	@name = Namen.all || false
	erb :zeige_namen
end

get '/xyz' do
  	ip = @env['REMOTE_ADDR']
  	obj = Votesecure.last(:ip => ip) || false
	@s = ""
	if obj != false then
     	@s = obj[:datum]
	end
	erb :last_ip
end


get '/*' do
	redirect '/'
end


__END__
@@last_ip
<%= @s.to_i.to_s %>
@@voten_hinweis
<span id="home">
<p>Bitte nicht zu oft voten oder Namen adden. Danke.</p>
</span>
@@home
<span id="home">
<p>Hallo Gast, bitte hilf uns bei der Namensfindung. Unser Baby braucht einen coolen Namen.
Gib deine Stimme für einen vorhandenen Namen ab oder mach einen eigenen Vorschlag.</p>
<p>Um abzustimmen klicke auf "Abstimmen" und dannach auf den Daumen neben dem Namen.
</p>
<p>Für einen neuen Vorschlag einfach "Neuer Name" wählen.</p>
@@zeige_namen
</span>

<span id="namen">
<table>
<th>Vorname</th><th>Zweitname</th><th>Stimmen</th><th>Liken</th>
<% @name.each do |n|%>
	<tr>
<td><%= n.vorname %></td><td><%= n.middlename %></td><td><%= n.votes %></td><td><a href="/abstimmen/<%=n.id%>"><img src="like.png"></img></a></td>
</tr>
<% end %>
</span>
</table>

@@neuer_name
<span id="formular">
<p>Hier kannst du einen Vor- und Zweitnamen eintragen.</p>
<form method="post" action="/neuer_name">
<label>Vorname:</label><input  name="vorname" type="vorname" required></input>
<label>Zweitname</label><input name="middlename" type="mittlerer_name" required></input>
<p><input type="submit"></input></p>
</form>
</span>
@@layout
<!doctype html5>
<meta charset="utf-8">
<html>
<head>
<script src="//www.google.com/jsapi"></script>
<script src="chartkick.js"></script>
<script>
function mainCtrl($scope,$timeout){
          var count = function() {
		geburtsdatum = new Date(2017, 07, 20, 12, 00, 0, 0);
		jetzt = Date.now();
		diff = geburtsdatum.valueOf() - jetzt.valueOf();
		$scope.diff = Math.round(diff/(1000*60*60*24));
                $scope.stunden = Math.round(diff/(1000*60*60*1));
                $scope.minuten = Math.round(diff/(1000*60*1*1));
                $scope.sekunden = Math.round(diff/(1000*1*1*1));
	        $timeout(count, 1000);
    }
    $timeout(count, 0);
}
</script>

<style type="text/css">
body {
	height:100%;
	width:100%;
	position: absolute;
}

#container
{
	height:100%;
	width:62%;
	float:left;

}
#header{
	text-shadow: 1px 2px 2px green;
	text-align: center;
	font-family: monospace;
	font-size:30px;
	width: 600px;
	height:100px;
	margin: 0 auto;
	clear:both;
}

#subheader{
	text-shadow: 1px 2px 10px black;
	text-align: center;
	font-family: sans-serif;
	width: 400px;
	height:70px;

	margin: 0 auto;
	clear:both;
}

#erklaerung{
	clear:both;
	height:50px;
}

#picture {
	background-image: url(./storch.png);
	background-repeat:no-repeat;
	width:500px;
	height: 267px;
	float:left;
}

#home {
	font-family: monospace;
  font-weight: bold;
  height:150px;

}
p {
	font-size:16px;
	font-family: monospace;
}

#main {
width:600px;
padding:10px;
clear:both;
}

#nav {


}
#nav ul {
	list-style-type: none;
}


#nav ul li {
	padding: 10px;
	display: inline;
}

#nav a {
	color:black;
	text-decoration: none;
	font-size:25px;
}

#nav a:hover {
	background-color:black;
	color:white;
	border: 15px;
  font-size:25px;
	font-weight: bold;
	border-color:black;
	border-style: solid;
}

#namen {
	font-family: sans-serif;
	width:600px;
}

#namen table {

}
#namen table th {
	padding-left:30px;
	font-size: 16px;
}
#namen table td {
	padding:3px;
	padding-left:10%;
}

#formular {
	width:500px;
}

p#votes {
	font-size: 12px;

	width:500px;
	text-align: center;
}

#formular label{
	display: block;
	font-family: monospace;
}
#formular input {
	padding:5px;
}

#charts {
	width:500px;
	padding:0px;
	float:left;
	clear:both;
}

#countdown {

	width:550px;
	text-align: center;
}

#countdown p {
	font-size:15px;
	color:green;
	text-shadow: 1px 1px 15px black;
	font-family: monospace;
}

#hinweis {
	font-size: 10px;
}

</style>
</head>

<body>

<div id="container">

<div id="picture">
</div>

<div id="header">
<h1><%= @header %></h1>
</div>

<div id="subheader">
<h2><%= @subheader %></h2>
</div>
<div id="countdown" ng-app>
	<div ng-controller="mainCtrl">
  <p>{{diff}} Tage | {{stunden}} Stunden
  | {{minuten}} Minuten | {{sekunden}} Sekunden<br>
bis der Storch kommt.</p>
	</div>
</div>
<div id="erklaerung">
<h4><%= @erklaerung %></h4>
<p id="votes">Bisher abgegebene Stimmen:
<%= get_all_vote_counts %></p>
</div>

<div id="nav">
<ul>
<li><a href="/"><img src="home.png">Home</img></a></li>
<li><a href="/zeige_namen"><img src="show_name.png">Abstimmen</img></a></li>
<li><a href="/neuer_name"><img src="add_name.png">Neuer Name</img></a></li>
</ul>
</div>

<div id="main">
<%= yield %>
</div>
<p id="hinweis"></p>
<div id="charts">
<% if get_hash_for_chart && (get_all_vote_counts > 0) %>
<%= pie_chart(get_hash_for_chart ) %>
<%= bar_chart get_hash_for_chart, height:"600px" %>
<% end %>
</div>
</div>
<script src="http://ajax.googleapis.com/ajax/libs/angularjs/1.2.27/angular.min.js"></script>
</body>
</html>
