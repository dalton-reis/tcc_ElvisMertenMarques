#import "TGGroupPlanController.h"
#import "GamePlanSymbols+GamePlanSymbolsController.h"
@implementation TGGroupPlanController

- (id)init
{
    self = [super init];
    if (self) {
        [self setManagedObjectContext:[(AppDelegate*)[UIApplication sharedApplication].delegate backgroundObjectContext]];
    }
    return self;
}

- (NSArray*)loadGroupPlansForSpecificUserWithID:(int)userID
{
    NSError *err;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc]init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"GroupPlan" inManagedObjectContext:[self managedObjectContext]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userID == %d", userID];
    
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    
    return [[self managedObjectContext]executeFetchRequest:fetchRequest error:&err];
}

- (NSArray*)loadGroupPlansForSpecificUserWithID:(int)userID andType:(int)type
{
    NSError *err;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc]init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"GroupPlan" inManagedObjectContext:[self managedObjectContext]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(type == %@) AND (userID == %d)", type, userID];
    
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    
    return [[self managedObjectContext]executeFetchRequest:fetchRequest error:&err];
}


- (NSArray*)loadPlansForGroupPlan:(GroupPlan*)groupPlan
              andForSpecificTutor:(int)tutorID
{
    NSError *err;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc]init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Plan" inManagedObjectContext:[self managedObjectContext]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(groupPlan == %@) AND (userID == %d)", groupPlan, tutorID];    
    
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    
    return [[self managedObjectContext]executeFetchRequest:fetchRequest error:&err];    
}

- (void)loadGroupPlansFromBackendWithSuccessHandler:(void(^)())successHandler
                                        failHandler:(void(^)(NSString *error))failHandler
{
    [[TGBackendAPIClient sharedAPIClient]getPath:@"/group_plans/index.json"
                                      parameters:nil
                                         success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                             if (operation) {
                                                 NSData *jsonData = [[operation responseString]dataUsingEncoding:NSUTF8StringEncoding];
                                                 NSDictionary *serverJson = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
                                                 if (serverJson) {
                                                     //TODO - sincronizar somente os grupos do usuário
                                                     for (NSDictionary *serverDic in serverJson) {
                                                         int serverID = [[serverDic objectForKey:@"id"]intValue];                                                         
                                                         if (![self groupPlanExistsWithID:serverID]) {
                                                             GroupPlan *gp = [NSEntityDescription insertNewObjectForEntityForName:@"GroupPlan" inManagedObjectContext:[self managedObjectContext]];
                                                             [gp setServerID:serverID];
                                                             [gp setName:[serverDic objectForKey:@"name"]];
                                                             [gp setUserID:[[serverDic objectForKey:@"user_id"]intValue]];
                                                             //parte para game e quebra cabeça
                                                             if ([[serverDic objectForKey:@"group_plan_type"] isKindOfClass:[NSNumber class]]) { 
                                                                 [gp setType:[[serverDic objectForKey:@"group_plan_type"] integerValue]];
                                                                 if (gp.type ==1) {
                                                                     [Game_plan_symbols loadSymbolsFromPlanGame:gp.serverID withCompletionBlock:^(NSDictionary *dic) {
                                                                         if (dic) {
                                                                             [Game_plan_symbols updateSymbolsFromGamePlan:gp.serverID withSymbols:dic];
                                                                         }
                                                                     }];
                                                                 }
                                                             }
                                                             
                                                             if (![[self managedObjectContext]save:nil]) {
                                                                 failHandler(NSLocalizedString(@"errorMessageInsertingCategory", nil));
                                                             }
                                                         }else {
                                                             if ([[serverDic objectForKey:@"group_plan_type"] isKindOfClass:[NSNumber class]]) {
                                                                 if ([serverDic objectForKey:@"group_plan_type"] ==[NSNumber numberWithInt:1]) {
                                                                     [Game_plan_symbols loadSymbolsFromPlanGame:[[serverDic objectForKey:@"id"] longValue] withCompletionBlock:^(NSDictionary *dic) {
                                                                         if (dic) {
                                                                             [Game_plan_symbols updateSymbolsFromGamePlan:[[serverDic objectForKey:@"id"] longValue] withSymbols:dic];
                                                                         }
                                                                     }];
                                                                 }
                                                             }
                                                         }
                                                     }
                                                     successHandler();
                                                 }
                                             }
                                         } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                             failHandler([error description]);
                                         }];
}

- (void)loadGroupPlanRelationshipsFromBackendWithSuccessHandler:(void(^)())successHandler
                                                    failHandler:(void(^)(NSString *error))failHandler
{
    [[TGBackendAPIClient sharedAPIClient]getPath:@"/group_plan_relationships/index.json"
                                      parameters:nil
                                         success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                             if (operation) {
                                                 NSData *jsonData = [[operation responseString]dataUsingEncoding:NSUTF8StringEncoding];
                                                 NSDictionary *serverJson = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
                                                 if (serverJson) {
                                                     for (NSDictionary *serverDic in serverJson) {
                                                         int serverID = [[serverDic objectForKey:@"id"]intValue];                                                         
                                                         if (![self groupPlanRelationshipExistsWithID:serverID]) {
                                                             GroupPlanRelationship *gp = [NSEntityDescription insertNewObjectForEntityForName:@"GroupPlanRelationship" inManagedObjectContext:[self managedObjectContext]];
                                                             [gp setServerID:serverID];
                                                             [gp setGroupPlan:[self groupPlanWithID:[[serverDic objectForKey:@"group_id"]intValue]]];
                                                             [gp setPlanID:[[serverDic objectForKey:@"plan_id"]intValue]];
                                                             
                                                             if (![[self managedObjectContext]save:nil]) {
                                                                 failHandler(NSLocalizedString(@"errorMessageInsertingCategory", nil));
                                                             }
                                                         }
                                                     }
                                                     successHandler();
                                                 }
                                             }
                                         } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                             failHandler([error description]);
                                         }];
    
}

- (BOOL)groupPlanExistsWithID:(int)serverID
{
    NSError *err;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc]init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"GroupPlan" inManagedObjectContext:[self managedObjectContext]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"serverID == %d", serverID];
    
    [fetchRequest setPredicate:predicate];
    [fetchRequest setEntity:entity];
    
    if ([[[self managedObjectContext]executeFetchRequest:fetchRequest error:&err]count] > 0) {
        return YES;
    }
    
    return NO;
}

- (BOOL)groupPlanRelationshipExistsWithID:(int)serverID
{
    NSError *err;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc]init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"GroupPlanRelationship" inManagedObjectContext:[self managedObjectContext]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"serverID == %d", serverID];
    
    [fetchRequest setPredicate:predicate];
    [fetchRequest setEntity:entity];
    
    if ([[[self managedObjectContext]executeFetchRequest:fetchRequest error:&err]count] > 0) {
        return YES;
    }
    
    return NO;
}

- (void)createGroupPlanWithName:(NSString *)name
                      andUserID:(int)userID
                       withType:(int)type
                 successHandler:(void(^)())successHandler
                    failHandler:(void(^)(NSString *error))failHandler
{
    if ([self connectionIsAvailable]) {
        [self createGroupPlanInBackendWithName:name
                                     andUserID:userID
                                      withType:type
                                successHandler:successHandler
                                   failHandler:failHandler];
    } else {
        [self createGroupPlanInDeviceWithName:name
                                    andUserID:userID
                                  andServerID:-1
                                     withType:type
                               successHandler:successHandler
                                  failHandler:failHandler];
    }
}

- (void)createGroupPlanInBackendWithName:(NSString *)name
                               andUserID:(int)userID
                                withType:(int)type
                          successHandler:(void(^)())successHandler
                             failHandler:(void(^)(NSString *error))failHandler
{
    id params = @{@"name": name, @"user_id": [NSNumber numberWithInt:userID], @"group_plan_type": [NSNumber numberWithInt:type]};
    
    [[TGBackendAPIClient sharedAPIClient]postPath:@"/group_plans/create.json"
                                       parameters:params
                                          success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                              if (operation) {
                                                  NSData *jsonData = [[operation responseString]dataUsingEncoding:NSUTF8StringEncoding];
                                                  NSDictionary *serverJson = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
                                                  if (serverJson) {                                                      
                                                      [self createGroupPlanInDeviceWithName:name andUserID:userID andServerID:[[serverJson objectForKey:@"id"]intValue] withType:type successHandler:successHandler failHandler:failHandler];
                                                  }
                                              }
                                          } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                              failHandler([error description]);
                                          }];
}

- (void)createGroupPlanRelationshipInBackendWithGroupPlan:(GroupPlan*)groupPlan
                                            andWithPlanID:(int)planID
                                           successHandler:(void(^)())successHandler
                                              failHandler:(void(^)(NSString *error))failHandler
{
    id params = @{@"group_id": [NSNumber numberWithInt:[groupPlan serverID]], @"plan_id": [NSNumber numberWithInt:planID]};
    
    [[TGBackendAPIClient sharedAPIClient]postPath:@"/group_plan_relationships/create.json"
                                       parameters:params
                                          success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                              if (operation) {
                                                  NSData *jsonData = [[operation responseString]dataUsingEncoding:NSUTF8StringEncoding];
                                                  NSDictionary *serverJson = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
                                                  if (serverJson) {
                                                      [self createGroupPlanRelationshipInDeviceWithGroupPlan:groupPlan andWithPlanID:planID andGroupPlanRelationshipServerID:[[serverJson objectForKey:@"id"]intValue] successHandler:successHandler failHandler:failHandler];
                                                  }
                                              }
                                          } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                              failHandler([error description]);
                                          }];
    
}

- (void)createGroupPlanRelationshipInDeviceWithGroupPlan:(GroupPlan*)groupPlan
                                           andWithPlanID:(int)planID
                        andGroupPlanRelationshipServerID:(int)serverID
                                          successHandler:(void(^)())successHandler
                                             failHandler:(void(^)(NSString *error))failHandler
{
    NSError *error;
    
    GroupPlanRelationship *gp = [NSEntityDescription insertNewObjectForEntityForName:@"GroupPlanRelationship" inManagedObjectContext:[self managedObjectContext]];
    [gp setServerID:serverID];
    [gp setGroupPlan:groupPlan];
    [gp setPlanID:planID];
    
    if (![[self managedObjectContext]save:&error]) {
        failHandler([error description]);
    } else {
        successHandler();
    }
}

- (void)createGroupPlanInDeviceWithName:(NSString *)name
                              andUserID:(int)userID
                            andServerID:(int)serverID
                               withType:(int)type
                         successHandler:(void(^)())successHandler
                            failHandler:(void(^)(NSString *error))failHandler
{
    NSError *error;
    
    GroupPlan *gp = [NSEntityDescription insertNewObjectForEntityForName:@"GroupPlan" inManagedObjectContext:[self managedObjectContext]];
    [gp setServerID:serverID];
    [gp setName:name];
    [gp setType:type];
    [gp setUserID:userID];
    
    if (![[self managedObjectContext]save:&error]) {
        failHandler([error description]);
    } else {
        successHandler();
    }
}

- (BOOL)connectionIsAvailable
{
    Reachability *networkReachability = [Reachability reachabilityWithHostName:GOOGLE];
    NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
    
    return (networkStatus == NotReachable) ? NO : YES;
}

- (GroupPlan*)groupPlanWithID:(int)groupPlanID
{
    NSError *err;
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc]init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"GroupPlan" inManagedObjectContext:[self managedObjectContext]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"serverID == %d", groupPlanID];
    
    [fetchRequest setPredicate:predicate];
    [fetchRequest setEntity:entity];
    
    NSArray *results = [[self managedObjectContext]executeFetchRequest:fetchRequest error:&err];
    
    if ([results count] > 0) {
        return [results objectAtIndex:0];
    }
    
    return nil;
}

- (GroupPlan*)groupPlanForPlanWithPlanID:(int)planID
{
    NSError *err;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc]init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"GroupPlanRelationship" inManagedObjectContext:[self managedObjectContext]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"planID == %d", planID];
    
    [fetchRequest setPredicate:predicate];
    [fetchRequest setEntity:entity];
    
    NSArray *results = [[self managedObjectContext]executeFetchRequest:fetchRequest error:&err];

    if ([results count] > 0) {
        GroupPlan *gp = [[results objectAtIndex:0]groupPlan];
        return gp;
    }
    
    return nil;
}



@end