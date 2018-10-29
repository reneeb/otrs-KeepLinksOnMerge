# --
# Copyright (C) 2016 - 2018 Perl-Services.de, http://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::KeepLinksOnMerge;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::Ticket
    Kernel::System::LinkObject
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');

    # check needed stuff
    for my $Needed (qw(Data Event Config)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    for my $NeededData (qw(TicketID MainTicketID)) {
        if ( !$Param{Data}->{$NeededData} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $NeededData in Data!"
            );
            return;
        }
    }

    my %Data     = %{ $Param{Data} || {} };
    my $LinkList = $LinkObject->LinkList(
        Object => 'Ticket',
        Key    => $Data{TicketID},
        State  => 'Valid',
        UserID => 1,
    );

    return 1 if !$LinkList || ref $LinkList ne 'HASH';

    my $LinkListMerged = $LinkObject->LinkList(
        Object => 'Ticket',
        Key    => $Data{MainTicketID},
        State  => 'Valid',
        UserID => 1,
    ) || {};

    my @Directions = qw(Source Target);
    my %DirectionsMap = (
        Source => 0,
        Target => 1,
    );

    for my $Object ( sort keys %{$LinkList} ) {
        my %ObjectLinks = %{ $LinkList->{$Object} || {} };

        for my $Type ( sort keys %ObjectLinks ) {
            for my $Direction ( keys %{ $ObjectLinks{$Type} || {} } ) {
                my %DirectedLinks = %{ $ObjectLinks{$Type}->{$Direction} || {} };
 
                OTHERID:
                for my $OtherID ( sort keys %DirectedLinks ) {

                     next OTHERID if $Object eq 'Ticket' && $OtherID == $Data{MainTicketID};
                     next OTHERID if $LinkListMerged->{$Object}->{$Type}->{$Direction}->{$OtherID};

                     my $TicketDirectionType = $Directions[ $DirectionsMap{$Direction} ^ 1 ];

                     $LinkObject->LinkAdd(
                         $TicketDirectionType . 'Object' => 'Ticket',
                         $TicketDirectionType . 'Key'    => $Data{MainTicketID},
                         $Direction . 'Object'           => $Object,
                         $Direction . 'Key'              => $OtherID,
                         Type                            => $Type,
                         State                           => 'Valid',
                         UserID                          => $Param{UserID},
                     );
                }
            }
        }
    }

    return 1;
}

1;
