# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 sven Dowideit, SvenDowideit@wikiring.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.

=pod

---+ package JSPopupPlugin


=cut

# change the package name and $pluginName!!!
package Foswiki::Plugins::JSPopupPlugin;

# Always use strict to enforce variable scoping
use strict;

use vars qw( $VERSION $RELEASE $debug $pluginName $WEB $TOPIC );
use vars qw( %FoswikiCompatibility $popupSectionNumber $pluginPubUrl );

$VERSION = '$Rev$';
$RELEASE = 'Foswiki';
$pluginName = 'JSPopupPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in


=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    setupFoswiki4Compatibility();
    Foswiki::Func::registerTagHandler( 'POPUP', \&handlePopup );
    Foswiki::Func::registerTagHandler( 'POPUPLINK', \&handlePopupLink );

    $WEB = $web;
    $TOPIC= $topic;
    $popupSectionNumber = 0;

   $pluginPubUrl = Foswiki::Func::getPubUrlPath().'/'.
            Foswiki::Func::getTwikiWebname().'/'.$pluginName;


    # Plugin correctly initialized
    return 1;
}


#this is only there to support the addition of HEAD sections
sub commonTagsHandler {
#    my ( $text, $topic, $web ) = @_;

#TODO: implement the regex for registerHandler
    return unless ($_[0] =~ /<\/head>/);
    return unless (keys(%{$FoswikiCompatibility{HEAD}}) > 0);

    my $query = Foswiki::Func::getCgiQuery();
    my $fromPopup = $query->param('fromPopup');
    return if (defined($fromPopup));#avoid nesting popups

        #fake up addToHead for cairo
    if ($Foswiki::Plugins::VERSION eq 1.025) {
        my $htmlHeader = join(
            "\n",
            map { '<!--'.$_.'-->'.$FoswikiCompatibility{HEAD}{$_} }
                keys %{$FoswikiCompatibility{HEAD}});
        $_[0] =~ s/([<]\/head[>])/$htmlHeader$1/i if $htmlHeader;
        chomp($_[0]);

        %{$FoswikiCompatibility{HEAD}} = ();
    }
}

#TODO: MAKE SOME URL PARAMS TO POPUP TOO - SO YOU GET POPUP OOPSES
#TODO:   * popuptexttype ="" - tml, rest
#TODO:      * TODO: delayedtml, javascript
#TODO:   * popuplocation="" - general location relative to the anchor (center, above, below, left, right) - center is default *TODO: only center and below are implemented*
#TODO:      * TODO: its currently relative to the mouse event, not the anchor
#TODO:      * TODO: add location on screen, not- relative to mouse.. (popup in top right)
#TODO:   * buttons="" - what buttons to show (ok, cancel, save...) *TODO*
#TODO:    * popuplocation="" - general location relative to the anchor (center, above, below, left, right) - center is default *TODO: only center and below are implemented*
sub handlePopup {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    my $default = $params->{_DEFAULT} || '';    #TODO: not sure what thus should be :)

    my $anchor = ' '.$params->{anchor}.' ';
    my $anchortype = $params->{anchortype} || 'onclick';
    $anchortype = 'anchorless' unless ((defined($anchor)) && ($anchor ne ''));
    my $popuptext = $params->{popuptext};
    my $fallbackurl = $params->{fallbackurl};
    $fallbackurl = $popuptext unless (defined($fallbackurl));
    my $popuptitle = $params->{popuptitle} || '';
    my $popuptexttype = $params->{popuptexttype} || 'tml';
    my $popuplocation = $params->{popuplocation} || 'center';
    my $border = $params->{border} || 'on';
    my $buttons = $params->{buttons};
    my $evaluate = $params->{eval};
    my $delay = $params->{delay} || '200';

    my $display = 'display:none;';
    my $event = '';

    my $output = '';
    if ($anchortype eq 'popuplink') {
        $event = 'return foswiki.JSPopupPlugin.openPopupSectional(event, \'popupSection'.$popupSectionNumber.'\');';#ASSUME onclick
        $output = $query->a({href=>$fallbackurl, onclick=>$event}, $anchor);
    } elsif ($anchortype eq 'anchorless') {
    } else {
        $event = 'onclick="return foswiki.JSPopupPlugin.openPopupSectional(event, \'popupSection'.$popupSectionNumber.'\');"';#ASSUME onclick
        if ($anchortype eq 'onmouseover') {
            $event = 'onmouseover="return foswiki.JSPopupPlugin.DelayedOpenPopupSectional(event, \'popupSection'.$popupSectionNumber.'\');return false;" onmouseout="return foswiki.JSPopupPlugin.CancelOpenPopup();"';
        }
        $output .= '<span '.$event.'>'."\n".$anchor."\n".'</span>';
    }

    #TODO: work out a way to mix tml mode in topic, and rest & delayedtml mode where it needs to be added in the postRenderingHandler (and can use JSON)
    if ($popuptexttype eq 'rest') {
        #nasty way to stop the url from getting Foswiki'd
    } else {
        $popuptext = "\n".$popuptext."\n";
        $popuptext =~ s/\$percnt/%/g;
    }
    
    #TODO: this should really get added outside the topic like InlineEdit
    $output .= '<span class="JSPopupSpan"'.
        'style="'.$display.
        '" id="popupSection'.$popupSectionNumber.
        '" anchortype="'.$anchortype.
        '" type="'.$popuptexttype.
        '" title="'.$popuptitle.
        '" location="'.$popuplocation.
        '" delay="'.$delay.
        '" border="'.$border.'">'.$popuptext.'</span>';


    $popupSectionNumber++;
    return $output;
}

sub handlePopupLink {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    my $anchor = $params->{_DEFAULT} || $params->{anchor} || 'Popup';
    my $url = $params->{url};
    
    my $popuptitle = $params->{popuptitle} || '';
    my $popuplocation = $params->{popuplocation} || 'center';
    my $border = $params->{border} || 'on';
    my $buttons = $params->{buttons};
    my $evaluate = $params->{eval};
    my $delay = $params->{delay} || '200';
    

    my $display = 'display:none;';
    my $event = 'return foswiki.JSPopupPlugin.openPopupSectional(event, \'popupSection'.$popupSectionNumber.'\');';#ASSUME onclick
    my $output = CGI::a(
                    {
                        id => 'popupSection'.$popupSectionNumber,
                        href =>     $url, 
                        popupurl =>     $url, 
                        type => 'rest',
                        location =>     $popuplocation,
                        delay =>    $delay,
                        border =>   $border,
                        title =>    $popuptitle,
                        
                        onclick=>   $event
                    }, 
                $anchor);


    $popupSectionNumber++;
    return $output;
}


sub postRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my $text = shift;

    my $query = Foswiki::Func::getCgiQuery();
    my $fromPopup = $query->param('fromPopup');
    return if (defined($fromPopup));#avoid nesting popups

    #add the  JavaScript
    my $jscript = Foswiki::Func::readTemplate ( 'jspopupplugin', 'javascript' );
    $jscript =~ s/%PLUGINPUBURL%/$pluginPubUrl/g;
    addToHEAD($pluginName, $jscript);

    #TODO: evaluate the MAKETEXT's, and the variables....
    my $templateText = Foswiki::Func::readTemplate ( 'jspopupplugin', 'popup' );
    $templateText =~ s/%PLUGINPUBURL%/$pluginPubUrl/g;
    $templateText = Foswiki::Func::expandCommonVariables( $templateText, $TOPIC, $WEB );

    $_[0] =~ s/(<\/body>)/$templateText $1/g;
}


##########################################################
#Cairo compat gumpf

# DEPRECATED in Dakar (postRenderingHandler does the job better)
# This handler is required to re-insert blocks that were removed to protect
# them from Foswiki rendering, such as Foswiki variables.
$FoswikiCompatibility{endRenderingHandler} = 1.1;
sub endRenderingHandler {
  return postRenderingHandler( @_ );
}


sub registerRESTHandler {
    if ($Foswiki::Plugins::VERSION eq 1.025) {
        my ($name, $funcRef) = @_;
        $FoswikiCompatibility{RESTHandlers}{$pluginName.'.'.$name} = $funcRef;
    } else {
        Foswiki::Func::registerRESTHandler(@_);
    }
}

#to fake Foswiki4 restHanders in Cairo, use the view script (url is different too :( view/WEB/TOPIC?rest=InlineEditPlugin.restHandlerFuncName)
#and add this sub to your beforeCommonTagsHandler
sub fakeFoswiki4RestHandlers {
    my ( $text, $topic, $web ) = @_;   #params passed on from beforeCommonTagsHandler
    #This is the view script based REST Handler cludge
   my $query = Foswiki::Func::getCgiQuery();
   my $restCall = $query->param('rest');
    if (defined ($restCall) && defined($FoswikiCompatibility{RESTHandlers}{$restCall})) {
        my $function = $FoswikiCompatibility{RESTHandlers}{$restCall};
        print $query->header(
                    -content_type => 'text',
             );
        no strict 'refs';
        my $session = {};
        $session->{cgiQuery} = $query;
        my $result='';
        $result=&$function($session,$web,$topic);
        print $result;
        exit 1;
    }
}


sub addToHEAD {
    if ($Foswiki::Plugins::VERSION eq 1.025) {
        my ($name, $text) = @_;
        $FoswikiCompatibility{HEAD}{$name} = $text;
    } else {
        Foswiki::Func::addToHEAD( @_ );
    }
}

sub setupFoswiki4Compatibility {
    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.025 ) {
        Foswiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm (tested on Cairo and Foswiki-4.0))" );
        return 0;
    } elsif ($Foswiki::Plugins::VERSION eq 1.025) {
        #Cairo
        %{$FoswikiCompatibility{HEAD}} = ();
        %{$FoswikiCompatibility{HEAD}} = ();
    } else {
        #Foswiki-4.0 and above
    }
}

1;

