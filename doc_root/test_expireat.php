<?php

$expire_date = '2012-12-31 23:59:59';
$timestamp = strtotime($expire_date);
//$timestamp = strtotime('+2 min');
header("X-RedisCache-expireat: $timestamp");

function setInCache($buffer)
{
    $buffer = str_replace('{{{uri}}}', $_SERVER['REQUEST_URI'], $buffer);
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
<div>Page url : {{{uri}}}</div>
<div>This page was generated at <?php echo $date; ?></div>
<div>This page will expire at <?php echo date("Y-m-d H:i:s", $timestamp); ?> (<?php echo $timestamp; ?>)</div>
</body>
</html>

<?php
$output = ob_get_contents();
ob_end_flush();
//var_dump($output);
