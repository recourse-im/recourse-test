test "Events come down the correct room",
   requires => [ local_user_fixture( with_events => 0 ), "can_sync" ],

   check => sub {
      my ( $user ) = @_;
      my @rooms;

      Future->needs_all( map {
         matrix_create_room( $user )
         ->on_done( sub {
            my ( $room_id ) = @_;
            log_if_fail("Registered new room $room_id");
            push @rooms, $room_id;
         });
      } 1 .. 30 )
      ->then( sub {
         matrix_sync( $user );
      })->then( sub {
         log_if_fail("First sync body", $_[0]);
         Future->needs_all( map {
            my $room_id = $_;

            matrix_send_room_text_message( $user, $room_id, body => "$room_id" )
            ->on_done( sub {
                log_if_fail("Sent message in room $room_id");
            });
         } @rooms );
      })->then( sub {
         matrix_sync_again( $user );
      })->then( sub {
         my ( $body ) = @_;
         log_if_fail("Second sync body", $body);
         my $room_id;

         foreach $room_id ( @rooms ) {
            my $room = $body->{rooms}{join}{$room_id};

            assert_json_keys( $room, qw( timeline ));
            @{ $room->{timeline}{events} } == 1 or die "Expected exactly one event";

            my $event = $room->{timeline}{events}[0];

            assert_eq( $event->{content}{body}, $room_id, "Event in the wrong room" );
         }

         Future->done(1);
      });
   };
