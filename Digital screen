<?php
if(isset($_GET['image'])) {
    $img = $_GET['image'];
    $info = getimagesize($img);
    if($info[2] <= 3) $source = getSource($info[2],$img);
    else exit("IMAGE TYPE NOT SUPPORTED");
    $width = $info[0];
    $height = $info[1];
    if($width<$height) {
        $source = imagerotate($source,90,0);
        $width = imagesx($source);
        $height = imagesy($source);
    }
    if($width*$height > 786432) {
        $scale = 1;
        while(round($width*$scale)*round($height*$scale) > 786432) {
            $scale -= 0.01;
        }
        $sw = round($width*$scale);
        $sh = round($height*$scale);
        $temp = imagecreatetruecolor($sw,$sh);
        imagecopyresampled($temp,$source,0,0,0,0,$sw,$sh,$width,$height);
        $source = $temp;
        $width = $sw;
        $height = $sh;
    }
    $s = $width."x".$height.":";
    $rep = chr(32);
    for($y=0;$y<$height;$y++) {
        for($x=0;$x<$width;$x++) {
            $rgb = imagecolorat($source,$x,$y);
            $r = ($rgb >> 16) & 0xFF;
            $r = $r < 32 ? $rep : chr($r);
            $g = ($rgb >> 8) & 0xFF;
            $g = $g < 32 ? $rep : chr($g);
            $b = $rgb & 0xFF;
            $b = $b < 32 ? $rep : chr($b);
            $s .= ($r.$g.$b);
        }
    }
    echo $s;
}
function getSource($type,$img) {
    if($type == 1) $source = imagecreatefromgif($img);
    elseif($type == 2) $source = imagecreatefromjpeg($img);
    elseif($type == 3) $source = imagecreatefrompng($img);
    return $source;
}
?>
