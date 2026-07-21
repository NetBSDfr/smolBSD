<?php
echo"
<!DOCTYPE html>
<html>
<body><head>
<style>

.base{
  border: solid 1px gray;
  text-align:center;
  width: max-content;
  border-radius: 5px;
  box-shadow: 5px 5px 5px gray;
  padding: 0.5em;}

#baseWrapper{
  display:flex;
  justify-content: space-around}

li{text-align:left;}

</style>
</head>";

echo "<h1>smolBSD 'nbmp' service</h1>
<div style='font-size:small;'>(<b>N</b>etBSD <b>B</b>ozohttpd <b>M</b>ariadb <b>P</b>hp)</div>";
echo "<h1 style='text-align:center;'>Example site</h1>";

echo "<div style='text-align:center;'>See <a href='info.php'>PHP info page</a>.</div>";
echo "<img src='smolBSD.png' style='height:10em; display:block; margin:1.5em auto;' />";


$mysqli = new mysqli("localhost", "root", "");

if ($mysqli->connect_error) {
    die("Erreur de connexion : " . $mysqli->connect_error);
}

// Bases to exclude from display.
$system_databases = [
    'mysql',
    'information_schema',
    'performance_schema',
    'sys',
    'test'
];

// Bases fetch.
$result = $mysqli->query("SHOW DATABASES");
echo "<div style='text-align:center; margin-bottom:1em;'>MariaDB content :</div>";
echo "<div id='baseWrapper'>";
while ($db = $result->fetch_row()) {
    $dbname = $db[0];

    if (in_array($dbname, $system_databases)) {
        continue;
    }

    echo "<div class='base'><div style='font-weight: bold;text-decoration: underline;'>$dbname</div>";

    $mysqli->select_db($dbname);

    // Tables fetch.
    $tables = $mysqli->query("SHOW TABLES");
    echo "<ul>";
    while ($table = $tables->fetch_row()) {
        echo "<li>" . $table[0] . "</li>";
    }
    echo "</li></div>";
}

$mysqli->close();
echo "</div></body></html>";
?>
