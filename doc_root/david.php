<?php

function manageTemplate($buffer)
{
    $buffer = str_replace('{{{uri}}}', $_SERVER['REQUEST_URI'], $buffer);
    return $buffer;
}

ob_start("manageTemplate");

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

<h2>Test de parsing SSI!</h2>
<div>
Le bloc ci-dessous est un ssi en file :<br/>
<!--# include file="/bloc_ssi.php" -->
</div>
<div>
Le bloc ci-dessous est un ssi en virtual :<br/>
<!--# include virtual="/bloc_ssi.php" -->
</div>
<div><!--# echo var="name" default="salut les SSI" --></div>
<div><!--# config timefmt="%s"--></div>


</body>
</html>

<?php
$output = ob_get_contents();
ob_end_flush();
//var_dump($output);
