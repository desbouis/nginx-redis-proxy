<?php

header("X-RedisCache-ttl: 60");

function setInCache($buffer)
{
    $buffer = str_replace('{{{uri}}}', $_SERVER['REQUEST_URI'], $buffer);
    //@todo : faire un "set $_SERVER['REQUEST_URI'] $buffer" dans redis
    return $buffer;
}

ob_start("setInCache");

$server = "nginx server";
$date = date('Y/m/d H:i:s');

?>
<html>
<head>
<title>Welcome to <?php echo $server; ?>!</title>
</head>
<body bgcolor="white" text="black">
<h1>Welcome to <?php echo $server; ?>!</h1>
<div>Url de cette page : {{{uri}}}</div>
<div>cette page a &eacute;t&eacute; g&eacute;n&eacute;r&eacute;e &agrave; <?php echo $date; ?></div>
</body>
</html>

<?php
$output = ob_get_contents();
ob_end_flush();
//var_dump($output);
