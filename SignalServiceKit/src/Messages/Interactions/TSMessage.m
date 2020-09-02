//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "TSMessage.h"
#import "AppContext.h"
#import "MIMETypeUtil.h"
#import "OWSContact.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "TSAttachment.h"
#import "TSAttachmentStream.h"
#import "TSQuotedMessage.h"
#import "TSThread.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <SignalServiceKit/OWSDisappearingMessagesJob.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

static const NSUInteger OWSMessageSchemaVersion = 4;

#pragma mark -

@interface TSMessage ()

@property (nonatomic, nullable) NSString *body;
@property (nonatomic, nullable) MessageBodyRanges *bodyRanges;

@property (nonatomic) uint32_t expiresInSeconds;
@property (nonatomic) uint64_t expireStartedAt;

/**
 * The version of the model class's schema last used to serialize this model. Use this to manage data migrations during
 * object de/serialization.
 *
 * e.g.
 *
 *    - (id)initWithCoder:(NSCoder *)coder
 *    {
 *      self = [super initWithCoder:coder];
 *      if (!self) { return self; }
 *      if (_schemaVersion < 2) {
 *        _newName = [coder decodeObjectForKey:@"oldName"]
 *      }
 *      ...
 *      _schemaVersion = 2;
 *    }
 */
@property (nonatomic, readonly) NSUInteger schemaVersion;

@property (nonatomic, nullable) TSQuotedMessage *quotedMessage;
@property (nonatomic, nullable) OWSContact *contactShare;
@property (nonatomic, nullable) OWSLinkPreview *linkPreview;
@property (nonatomic, nullable) MessageSticker *messageSticker;

@property (nonatomic) BOOL isViewOnceMessage;
@property (nonatomic) BOOL isViewOnceComplete;
@property (nonatomic) BOOL wasRemotelyDeleted;

// This property is only intended to be used by GRDB queries.
@property (nonatomic, readonly) BOOL storedShouldStartExpireTimer;

@end

#pragma mark -

@implementation TSMessage

- (instancetype)initMessageWithBuilder:(TSMessageBuilder *)messageBuilder
{
    self = [super initInteractionWithTimestamp:messageBuilder.timestamp thread:messageBuilder.thread];

    if (!self) {
        return self;
    }

    _schemaVersion = OWSMessageSchemaVersion;

    if (messageBuilder.messageBody.length > 0) {
        _body = messageBuilder.messageBody;
        _bodyRanges = messageBuilder.bodyRanges;
    } else if (messageBuilder.messageBody != nil) {
        OWSFailDebug(@"Empty message body.");
    }
    _attachmentIds = messageBuilder.attachmentIds;
    _expiresInSeconds = messageBuilder.expiresInSeconds;
    _expireStartedAt = messageBuilder.expireStartedAt;
    [self updateExpiresAt];
    _quotedMessage = messageBuilder.quotedMessage;
    _contactShare = messageBuilder.contactShare;
    _linkPreview = messageBuilder.linkPreview;
    _messageSticker = messageBuilder.messageSticker;
    _isViewOnceMessage = messageBuilder.isViewOnceMessage;
    _isViewOnceComplete = NO;

#ifdef DEBUG
    [self verifyPerConversationExpiration];
#endif

    return self;
}

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
             receivedAtTimestamp:(uint64_t)receivedAtTimestamp
                          sortId:(uint64_t)sortId
                       timestamp:(uint64_t)timestamp
                  uniqueThreadId:(NSString *)uniqueThreadId
                   attachmentIds:(NSArray<NSString *> *)attachmentIds
                            body:(nullable NSString *)body
                      bodyRanges:(nullable MessageBodyRanges *)bodyRanges
                    contactShare:(nullable OWSContact *)contactShare
                 expireStartedAt:(uint64_t)expireStartedAt
                       expiresAt:(uint64_t)expiresAt
                expiresInSeconds:(unsigned int)expiresInSeconds
              isViewOnceComplete:(BOOL)isViewOnceComplete
               isViewOnceMessage:(BOOL)isViewOnceMessage
                     linkPreview:(nullable OWSLinkPreview *)linkPreview
                  messageSticker:(nullable MessageSticker *)messageSticker
                   quotedMessage:(nullable TSQuotedMessage *)quotedMessage
    storedShouldStartExpireTimer:(BOOL)storedShouldStartExpireTimer
              wasRemotelyDeleted:(BOOL)wasRemotelyDeleted
{
    self = [super initWithGrdbId:grdbId
                        uniqueId:uniqueId
               receivedAtTimestamp:receivedAtTimestamp
                            sortId:sortId
                         timestamp:timestamp
                    uniqueThreadId:uniqueThreadId];

    if (!self) {
        return self;
    }

    _attachmentIds = attachmentIds;
    _body = body;
    _bodyRanges = bodyRanges;
    _contactShare = contactShare;
    _expireStartedAt = expireStartedAt;
    _expiresAt = expiresAt;
    _expiresInSeconds = expiresInSeconds;
    _isViewOnceComplete = isViewOnceComplete;
    _isViewOnceMessage = isViewOnceMessage;
    _linkPreview = linkPreview;
    _messageSticker = messageSticker;
    _quotedMessage = quotedMessage;
    _storedShouldStartExpireTimer = storedShouldStartExpireTimer;
    _wasRemotelyDeleted = wasRemotelyDeleted;

    [self sdsFinalizeMessage];

    return self;
}

// clang-format on

// --- CODE GENERATION MARKER

- (void)sdsFinalizeMessage
{
#ifdef DEBUG
    [self verifyPerConversationExpiration];
#endif

    [self updateExpiresAt];
}

- (void)verifyPerConversationExpiration
{
    if (_expireStartedAt > 0 || _expiresAt > 0) {
        // It only makes sense to set expireStartedAt and expiresAt for messages
        // with per-conversation expiration, e.g. expiresInSeconds > 0.
        // If either expireStartedAt and expiresAt are set, both should be set.
        //        OWSAssertDebug(_expiresInSeconds > 0);
        //        OWSAssertDebug(_expireStartedAt > 0);
        //        OWSAssertDebug(_expiresAt > 0);
    }
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return self;
    }

    if (_schemaVersion < 2) {
        // renamed _attachments to _attachmentIds
        if (!_attachmentIds) {
            _attachmentIds = [coder decodeObjectForKey:@"attachments"];
        }
    }

    if (_schemaVersion < 3) {
        _expiresInSeconds = 0;
        _expireStartedAt = 0;
        _expiresAt = 0;
    }

    if (_schemaVersion < 4) {
        // Wipe out the body field on these legacy attachment messages.
        //
        // Explantion: Historically, a message sent from iOS could be an attachment XOR a text message,
        // but now we support sending an attachment+caption as a single message.
        //
        // Other clients have supported sending attachment+caption in a single message for a long time.
        // So the way we used to handle receiving them was to make it look like they'd sent two messages:
        // first the attachment+caption (we'd ignore this caption when rendering), followed by a separate
        // message with just the caption (which we'd render as a simple independent text message), for
        // which we'd offset the timestamp by a little bit to get the desired ordering.
        //
        // Now that we can properly render an attachment+caption message together, these legacy "dummy" text
        // messages are not only unnecessary, but worse, would be rendered redundantly. For safety, rather
        // than building the logic to try to find and delete the redundant "dummy" text messages which users
        // have been seeing and interacting with, we delete the body field from the attachment message,
        // which iOS users have never seen directly.
        if (_attachmentIds.count > 0) {
            _body = nil;
        }
    }

    if (!_attachmentIds) {
        _attachmentIds = @[];
    }

    _schemaVersion = OWSMessageSchemaVersion;

    // Upgrades legacy messages.
    //
    // TODO: We can eventually remove this migration since
    //       per-message expiration was never released to
    //       production.
    NSNumber *_Nullable perMessageExpirationDurationSeconds =
        [coder decodeObjectForKey:@"perMessageExpirationDurationSeconds"];
    if (perMessageExpirationDurationSeconds.unsignedIntegerValue > 0) {
        _isViewOnceMessage = YES;
    }
    NSNumber *_Nullable perMessageExpirationHasExpired = [coder decodeObjectForKey:@"perMessageExpirationHasExpired"];
    if (perMessageExpirationHasExpired.boolValue > 0) {
        _isViewOnceComplete = YES;
    }

    return self;
}

- (void)setExpiresInSeconds:(uint32_t)expiresInSeconds
{
    uint32_t maxExpirationDuration = [OWSDisappearingMessagesConfiguration maxDurationSeconds];
    if (expiresInSeconds > maxExpirationDuration) {
        OWSFailDebug(@"using `maxExpirationDuration` instead of: %u", maxExpirationDuration);
    }

    _expiresInSeconds = MIN(expiresInSeconds, maxExpirationDuration);
    [self updateExpiresAt];
}

- (void)setExpireStartedAt:(uint64_t)expireStartedAt
{
    if (_expireStartedAt != 0 && _expireStartedAt < expireStartedAt) {
        OWSLogDebug(@"ignoring later startedAt time");
        return;
    }

    uint64_t now = [NSDate ows_millisecondTimeStamp];
    if (expireStartedAt > now) {
        OWSLogWarn(@"using `now` instead of future time");
    }

    _expireStartedAt = MIN(now, expireStartedAt);

    [self updateExpiresAt];
}

// This method will be called after every insert and update, so it needs
// to be cheap.
- (BOOL)shouldStartExpireTimer
{
    if (self.hasPerConversationExpirationStarted) {
        // Expiration already started.
        return YES;
    }

    return self.hasPerConversationExpiration;
}

- (void)updateExpiresAt
{
    if (self.hasPerConversationExpirationStarted) {
        _expiresAt = _expireStartedAt + _expiresInSeconds * 1000;
    } else {
        _expiresAt = 0;
    }
}

#pragma mark - Attachments

- (BOOL)hasAttachments
{
    return self.attachmentIds ? (self.attachmentIds.count > 0) : NO;
}

- (NSArray<NSString *> *)allAttachmentIds
{
    NSMutableArray<NSString *> *result = [NSMutableArray new];
    if (self.attachmentIds.count > 0) {
        [result addObjectsFromArray:self.attachmentIds];
    }

    if (self.quotedMessage) {
        [result addObjectsFromArray:self.quotedMessage.thumbnailAttachmentStreamIds];

        if (self.quotedMessage.thumbnailAttachmentPointerId != nil) {
            [result addObject:self.quotedMessage.thumbnailAttachmentPointerId];
        }
    }

    if (self.contactShare.avatarAttachmentId) {
        [result addObject:self.contactShare.avatarAttachmentId];
    }

    if (self.linkPreview.imageAttachmentId) {
        [result addObject:self.linkPreview.imageAttachmentId];
    }

    if (self.messageSticker.attachmentId) {
        [result addObject:self.messageSticker.attachmentId];
    }

    // Use a set to de-duplicate the result.
    return [NSSet setWithArray:result].allObjects;
}

- (NSArray<TSAttachment *> *)bodyAttachmentsWithTransaction:(GRDBReadTransaction *)transaction
{
    return [self allAttachmentsWithTransaction:transaction];
}

- (NSArray<TSAttachment *> *)allAttachmentsWithTransaction:(GRDBReadTransaction *)transaction
{
    return [AttachmentFinder attachmentsWithAttachmentIds:self.attachmentIds transaction:transaction];
}

- (NSArray<TSAttachment *> *)bodyAttachmentsWithTransaction:(GRDBReadTransaction *)transaction
                                                contentType:(NSString *)contentType
{
    return [AttachmentFinder attachmentsWithAttachmentIds:self.attachmentIds
                                      matchingContentType:contentType
                                              transaction:transaction];
}

- (NSArray<TSAttachment *> *)bodyAttachmentsWithTransaction:(GRDBReadTransaction *)transaction
                                          exceptContentType:(NSString *)contentType
{
    return [AttachmentFinder attachmentsWithAttachmentIds:self.attachmentIds
                                      ignoringContentType:contentType
                                              transaction:transaction];
}

- (void)removeAttachment:(TSAttachment *)attachment transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug([self.attachmentIds containsObject:attachment.uniqueId]);
    [attachment anyRemoveWithTransaction:transaction];

    [self anyUpdateMessageWithTransaction:transaction
                                    block:^(TSMessage *message) {
                                        NSMutableArray<NSString *> *attachmentIds = [message.attachmentIds mutableCopy];
                                        [attachmentIds removeObject:attachment.uniqueId];
                                        message.attachmentIds = [attachmentIds copy];
                                    }];
}

- (NSString *)debugDescription
{
    if ([self hasAttachments] && self.body.length > 0) {
        NSString *attachmentId = self.attachmentIds[0];
        return [NSString
            stringWithFormat:@"Media Message with attachmentId: %@ and caption: '%@'", attachmentId, self.body];
    } else if ([self hasAttachments]) {
        NSString *attachmentId = self.attachmentIds[0];
        return [NSString stringWithFormat:@"Media Message with attachmentId: %@", attachmentId];
    } else {
        return [NSString stringWithFormat:@"%@ with body: %@ has mentions: %@",
                         [self class],
                         self.body,
                         self.bodyRanges.hasMentions ? @"YES" : @"NO"];
    }
}

- (nullable TSAttachment *)oversizeTextAttachmentWithTransaction:(GRDBReadTransaction *)transaction
{
    return [self bodyAttachmentsWithTransaction:transaction contentType:OWSMimeTypeOversizeTextMessage].firstObject;
}

- (BOOL)hasMediaAttachmentsWithTransaction:(GRDBReadTransaction *)transaction
{
    return [AttachmentFinder existsAttachmentsWithAttachmentIds:self.attachmentIds
                                            ignoringContentType:OWSMimeTypeOversizeTextMessage
                                                    transaction:transaction];
}

- (NSArray<TSAttachment *> *)mediaAttachmentsWithTransaction:(GRDBReadTransaction *)transaction
{
    return [self bodyAttachmentsWithTransaction:transaction exceptContentType:OWSMimeTypeOversizeTextMessage];
}

- (nullable NSString *)oversizeTextWithTransaction:(GRDBReadTransaction *)transaction
{
    TSAttachment *_Nullable attachment = [self oversizeTextAttachmentWithTransaction:transaction];
    if (!attachment) {
        return nil;
    }

    if (![attachment isKindOfClass:TSAttachmentStream.class]) {
        return nil;
    }

    TSAttachmentStream *attachmentStream = (TSAttachmentStream *)attachment;

    NSData *_Nullable data = [NSData dataWithContentsOfFile:attachmentStream.originalFilePath];
    if (!data) {
        //        OWSFailDebug(@"Can't load oversize text data.");
        return nil;
    }
    NSString *_Nullable text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) {
        OWSFailDebug(@"Can't parse oversize text data.");
        return nil;
    }
    return text;
}

- (nullable NSString *)rawBodyWithTransaction:(GRDBReadTransaction *)transaction
{
    NSString *_Nullable oversizeText = [self oversizeTextWithTransaction:transaction];
    if (oversizeText) {
        return oversizeText;
    }

    if (self.body.length > 0) {
        return self.body;
    }

    return nil;
}

- (nullable NSString *)plaintextBodyWithTransaction:(GRDBReadTransaction *)transaction
{
    NSString *_Nullable rawBody = [self rawBodyWithTransaction:transaction];
    if (rawBody) {
        if (self.bodyRanges) {
            return [self.bodyRanges plaintextBodyWithText:rawBody transaction:transaction];
        }

        return rawBody.filterStringForDisplay;
    }

    return nil;
}

// TODO: This method contains view-specific logic and probably belongs in NotificationsManager, not in SSK.
- (NSString *)previewTextWithTransaction:(SDSAnyReadTransaction *)transaction
{
    if (self.wasRemotelyDeleted) {
        return [self isKindOfClass:[TSIncomingMessage class]]
            ? NSLocalizedString(@"THIS_MESSAGE_WAS_DELETED", "text indicating the message was remotely deleted")
            : NSLocalizedString(@"YOU_DELETED_THIS_MESSAGE", "text indicating the message was remotely deleted by you");
    }

    NSString *_Nullable bodyDescription = nil;

    if (self.body.length > 0) {
        bodyDescription = self.body;
    }

    if (self.bodyRanges) {
        bodyDescription = [self.bodyRanges plaintextBodyWithText:bodyDescription
                                                     transaction:transaction.unwrapGrdbRead];
    }

    if (bodyDescription == nil) {
        TSAttachment *_Nullable oversizeTextAttachment =
            [self oversizeTextAttachmentWithTransaction:transaction.unwrapGrdbRead];
        if ([oversizeTextAttachment isKindOfClass:[TSAttachmentStream class]]) {
            TSAttachmentStream *oversizeTextAttachmentStream = (TSAttachmentStream *)oversizeTextAttachment;
            NSData *_Nullable data = [NSData dataWithContentsOfFile:oversizeTextAttachmentStream.originalFilePath];
            if (data) {
                NSString *_Nullable text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (text) {
                    bodyDescription = text.filterStringForDisplay;
                }
            }
        }
    }

    NSString *_Nullable attachmentEmoji = nil;
    NSString *_Nullable attachmentDescription = nil;

    TSAttachment *_Nullable mediaAttachment =
        [self mediaAttachmentsWithTransaction:transaction.unwrapGrdbRead].firstObject;
    if (mediaAttachment != nil) {
        attachmentEmoji = mediaAttachment.emoji;
        attachmentDescription = mediaAttachment.description;
    }

    if (self.isViewOnceMessage) {
        if ([self isKindOfClass:TSOutgoingMessage.class]) {
            return NSLocalizedString(@"PER_MESSAGE_EXPIRATION_NOT_VIEWABLE",
                @"inbox cell and notification text for an already viewed view-once media message.");
        } else {
            if (mediaAttachment == nil) {
                return NSLocalizedString(@"PER_MESSAGE_EXPIRATION_NOT_VIEWABLE",
                    @"inbox cell and notification text for an already viewed view-once media message.");
            } else {
                if (mediaAttachment.isVideo) {
                    return NSLocalizedString(@"PER_MESSAGE_EXPIRATION_VIDEO_PREVIEW",
                        @"inbox cell and notification text for a view-once video.");
                } else {
                    OWSAssertDebug(mediaAttachment.isImage);
                    return NSLocalizedString(@"PER_MESSAGE_EXPIRATION_PHOTO_PREVIEW",
                        @"inbox cell and notification text for a view-once photo.");
                }
            }
        }
    }

    if (attachmentEmoji.length > 0 && bodyDescription.length > 0) {
        // Attachment with caption.
        return [[attachmentEmoji stringByAppendingString:@" "] stringByAppendingString:bodyDescription];
    } else if (bodyDescription.length > 0) {
        return bodyDescription;
    } else if (attachmentDescription.length > 0) {
        return attachmentDescription;
    } else if (self.contactShare) {
        return [[@"👤" stringByAppendingString:@" "] stringByAppendingString:self.contactShare.name.displayName];
    } else if (self.messageSticker) {
        NSString *stickerDescription = NSLocalizedString(@"STICKER_MESSAGE_PREVIEW",
            @"Preview text shown in notifications and conversation list for sticker messages.");
        NSString *_Nullable stickerEmoji = [StickerManager firstEmojiInEmojiString:self.messageSticker.emoji];
        if (stickerEmoji.length > 0) {
            return [[stickerEmoji stringByAppendingString:@" "] stringByAppendingString:stickerDescription];
        } else {
            return stickerDescription;
        }
    } else {
        // This can happen when initially saving outgoing messages
        // with camera first capture over the conversation list.
        return @"";
    }
}

- (void)anyWillInsertWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyWillInsertWithTransaction:transaction];

    // StickerManager does reference counting of "known" sticker packs.
    if (self.messageSticker != nil) {
        BOOL willInsert = (self.uniqueId.length < 1
            || nil == [TSMessage anyFetchWithUniqueId:self.uniqueId transaction:transaction]);

        if (willInsert) {
            [StickerManager addKnownStickerInfo:self.messageSticker.info transaction:transaction];
        }
    }

    // If we have any mentions, we need to save them to aid in querying
    // for messages that mention a given user. We only need to save one
    // mention record per UUID, even if the same UUID is mentioned
    // multiple times in the message.
    if (self.bodyRanges.hasMentions) {
        NSSet<NSUUID *> *uniqueMentionUuids = [NSSet setWithArray:self.bodyRanges.mentions.allValues];
        for (NSUUID *uuid in uniqueMentionUuids) {
            TSMention *mention = [[TSMention alloc] initWithUniqueMessageId:self.uniqueId
                                                             uniqueThreadId:self.uniqueThreadId
                                                                 uuidString:uuid.UUIDString];
            [mention anyInsertWithTransaction:transaction];
        }
    }

    [self updateStoredShouldStartExpireTimer];

#ifdef DEBUG
    [self verifyPerConversationExpiration];
#endif
}

- (void)anyDidInsertWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyDidInsertWithTransaction:transaction];

    [self ensurePerConversationExpirationWithTransaction:transaction];
}

- (void)anyWillUpdateWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyWillUpdateWithTransaction:transaction];

    [self updateStoredShouldStartExpireTimer];

#ifdef DEBUG
    [self verifyPerConversationExpiration];
#endif
}

- (void)anyDidUpdateWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyDidUpdateWithTransaction:transaction];

    [self ensurePerConversationExpirationWithTransaction:transaction];
}

- (void)ensurePerConversationExpirationWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    if (self.hasPerConversationExpirationStarted) {
        // Expiration already started.
        return;
    }
    if (![self shouldStartExpireTimer]) {
        return;
    }
    uint64_t nowMs = [NSDate ows_millisecondTimeStamp];
    [[OWSDisappearingMessagesJob sharedJob] startAnyExpirationForMessage:self
                                                     expirationStartedAt:nowMs
                                                             transaction:transaction];
}

- (void)updateStoredShouldStartExpireTimer
{
    _storedShouldStartExpireTimer = [self shouldStartExpireTimer];
}

- (void)anyWillRemoveWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyWillRemoveWithTransaction:transaction];

    // StickerManager does reference counting of "known" sticker packs.
    if (self.messageSticker != nil) {
        BOOL willDelete = (self.uniqueId.length > 0
            && nil != [TSMessage anyFetchWithUniqueId:self.uniqueId transaction:transaction]);

        // StickerManager does reference counting of "known" sticker packs.
        if (willDelete) {
            [StickerManager removeKnownStickerInfo:self.messageSticker.info transaction:transaction];
        }
    }
}

- (void)anyDidRemoveWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyDidRemoveWithTransaction:transaction];

    [self removeAllAttachmentsWithTransaction:transaction];

    [self removeAllReactionsWithTransaction:transaction];

    // This path gets hit during the YDB->GRDB migration *tests*, at which point
    // it's unsafe to assume we have a GRDB transaction. We can safely skip this
    // step during the tests when we don't.
    if (!transaction.isYapWrite) {
        [self removeAllMentionsWithTransaction:transaction];
    }
}

- (void)removeAllAttachmentsWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);

    for (NSString *attachmentId in self.allAttachmentIds) {
        // We need to fetch each attachment, since [TSAttachment removeWithTransaction:] does important work.
        TSAttachment *_Nullable attachment = [TSAttachment anyFetchWithUniqueId:attachmentId transaction:transaction];
        if (!attachment) {
            if (self.shouldBeSaved) {
                OWSFailDebugUnlessRunningTests(@"couldn't load interaction's attachment for deletion.");
            } else {
                OWSLogWarn(@"couldn't load interaction's attachment for deletion.");
            }
            continue;
        }
        [attachment anyRemoveWithTransaction:transaction];
    };
}

- (void)removeAllMentionsWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [MentionFinder deleteAllMentionsFor:self transaction:transaction.unwrapGrdbWrite];
}

- (BOOL)hasPerConversationExpiration
{
    return self.expiresInSeconds > 0;
}

- (BOOL)hasPerConversationExpirationStarted
{
    return _expireStartedAt > 0 && _expiresInSeconds > 0;
}

- (uint64_t)timestampForLegacySorting
{
    if ([self shouldUseReceiptDateForSorting] && self.receivedAtTimestamp > 0) {
        return self.receivedAtTimestamp;
    } else {
        OWSAssertDebug(self.timestamp > 0);
        return self.timestamp;
    }
}

- (BOOL)shouldUseReceiptDateForSorting
{
    return YES;
}

- (nullable NSString *)body
{
    return _body.filterStringForDisplay;
}

- (void)setQuotedMessageThumbnailAttachmentStream:(TSAttachmentStream *)attachmentStream
{
    OWSAssertDebug([attachmentStream isKindOfClass:[TSAttachmentStream class]]);
    OWSAssertDebug(self.quotedMessage);
    OWSAssertDebug(self.quotedMessage.quotedAttachments.count == 1);

    [self.quotedMessage setThumbnailAttachmentStream:attachmentStream];
}

#pragma mark - Update With... Methods

- (void)updateWithExpireStartedAt:(uint64_t)expireStartedAt transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(expireStartedAt > 0);
    OWSAssertDebug(self.expiresInSeconds > 0);

    [self anyUpdateMessageWithTransaction:transaction
                                    block:^(TSMessage *message) {
                                        [message setExpireStartedAt:expireStartedAt];
                                    }];
}

- (void)updateWithLinkPreview:(OWSLinkPreview *)linkPreview transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(linkPreview);
    OWSAssertDebug(transaction);

    [self anyUpdateMessageWithTransaction:transaction
                                    block:^(TSMessage *message) {
                                        [message setLinkPreview:linkPreview];
                                    }];
}

- (void)updateWithMessageSticker:(MessageSticker *)messageSticker transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(messageSticker);
    OWSAssertDebug(transaction);

    [self anyUpdateMessageWithTransaction:transaction
                                    block:^(TSMessage *message) {
                                        message.messageSticker = messageSticker;
                                    }];
}

#ifdef TESTABLE_BUILD

// This method is for testing purposes only.
- (void)updateWithMessageBody:(nullable NSString *)messageBody transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);

    [self anyUpdateMessageWithTransaction:transaction
                                    block:^(TSMessage *message) {
                                        message.body = messageBody;
                                    }];
}

#endif

#pragma mark - Renderable Content

- (BOOL)hasRenderableContent
{
    return (
        self.body.length > 0 || self.attachmentIds.count > 0 || self.contactShare != nil || self.messageSticker != nil);
}

#pragma mark - View Once

- (void)updateWithViewOnceCompleteAndRemoveRenderableContentWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);
    OWSAssertDebug(self.isViewOnceMessage);
    OWSAssertDebug(!self.isViewOnceComplete);

    [self removeAllRenderableContentWithTransaction:transaction
                                              block:^(TSMessage *message) {
                                                  message.isViewOnceComplete = YES;
                                              }];
}

#pragma mark - Remote Delete

- (void)updateWithRemotelyDeletedAndRemoveRenderableContentWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);
    OWSAssertDebug(!self.wasRemotelyDeleted);

    [self removeAllReactionsWithTransaction:transaction];

    [self removeAllRenderableContentWithTransaction:transaction
                                              block:^(TSMessage *message) {
                                                  message.wasRemotelyDeleted = YES;
                                              }];
}

- (void)removeAllRenderableContentWithTransaction:(SDSAnyWriteTransaction *)transaction
                                            block:(void (^)(TSMessage *message))block
{
    // We call removeAllAttachmentsWithTransaction() before
    // anyUpdateWithTransaction, because anyUpdateWithTransaction's
    // block can be called twice, once on this instance and once
    // on the copy from the database.  We only want to remove
    // attachments once.
    [self anyReloadWithTransaction:transaction ignoreMissing:YES];
    [self removeAllAttachmentsWithTransaction:transaction];
    [self removeAllMentionsWithTransaction:transaction];

    [self anyUpdateMessageWithTransaction:transaction
                                    block:^(TSMessage *message) {
                                        // Remove renderable content.
                                        message.body = nil;
                                        message.bodyRanges = nil;
                                        message.contactShare = nil;
                                        message.quotedMessage = nil;
                                        message.linkPreview = nil;
                                        message.messageSticker = nil;
                                        message.attachmentIds = @[];
                                        OWSAssertDebug(!message.hasRenderableContent);

                                        block(message);
                                    }];
}

@end

NS_ASSUME_NONNULL_END
