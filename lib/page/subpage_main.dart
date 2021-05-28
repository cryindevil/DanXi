/*
 *     Copyright (C) 2021  DanXi-Dev
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:dan_xi/common/constant.dart';
import 'package:dan_xi/feature/aao_notice_feature.dart';
import 'package:dan_xi/feature/custom_shortcut.dart';
import 'package:dan_xi/feature/dining_hall_crowdedness_feature.dart';
import 'package:dan_xi/feature/ecard_balance_feature.dart';
import 'package:dan_xi/feature/empty_classroom_feature.dart';
import 'package:dan_xi/feature/fudan_daily_feature.dart';
import 'package:dan_xi/feature/next_course_feature.dart';
import 'package:dan_xi/feature/qr_feature.dart';
import 'package:dan_xi/feature/welcome_feature.dart';
import 'package:dan_xi/generated/l10n.dart';
import 'package:dan_xi/page/dashboard_reorder.dart';
import 'package:dan_xi/page/platform_subpage.dart';
import 'package:dan_xi/provider/settings_provider.dart';
import 'package:dan_xi/public_extension_methods.dart';
import 'package:dan_xi/util/screen_proxy.dart';
import 'package:dan_xi/util/stream_listener.dart';
import 'package:dan_xi/widget/feature_item/feature_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeSubpage extends PlatformSubpage {
  @override
  bool get needPadding => true;

  @override
  bool get needBottomPadding => true;

  @override
  _HomeSubpageState createState() => _HomeSubpageState();

  HomeSubpage({Key key});
}

class RefreshHomepageEvent {
  final bool queueRefresh;
  final bool onlyIfQueued;
  RefreshHomepageEvent({this.queueRefresh = false, this.onlyIfQueued = false});
}

class _HomeSubpageState extends State<HomeSubpage> {
  static final StateStreamListener _refreshSubscription = StateStreamListener();
  SharedPreferences _preferences;
  Map<String, Widget> widgetMap;

  bool isRefreshQueued = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _refreshSubscription.bindOnlyInvalid(
        Constant.eventBus.on<RefreshHomepageEvent>().listen((event) {
          if (event.queueRefresh)
            isRefreshQueued = true;
          else if (event.onlyIfQueued) {
            isRefreshQueued = false;
            refreshSelf();
          } else {
            _rebuild();
            refreshSelf();
          }
        }),
        hashCode);
  }

  @override
  void didChangeDependencies() {
    _preferences = Provider.of<SharedPreferences>(context);
    _rebuild();
    super.didChangeDependencies();
  }

  /// This function refreshes the content of Dashboard
  /// Call this when new (online) data should be loaded.
  void _rebuild() {
    widgetMap = {
      'welcome_feature': FeatureListItem(
        feature: WelcomeFeature(),
      ),
      'next_course_feature': FeatureListItem(
        feature: NextCourseFeature(),
      ),
      'divider': Divider(),
      'ecard_balance_feature': FeatureListItem(
        feature: EcardBalanceFeature(),
      ),
      'dining_hall_crowdedness_feature': FeatureListItem(
        feature: DiningHallCrowdednessFeature(),
      ),
      'aao_notice_feature': FeatureListItem(
        feature: FudanAAONoticesFeature(),
      ),
      'empty_classroom_feature': FeatureListItem(
        feature: EmptyClassroomFeature(),
      ),
      'fudan_daily_feature': FeatureListItem(
        feature: FudanDailyFeature(),
      ),
      'new_card': Container(),
      'qr_feature': FeatureListItem(
        feature: QRFeature(),
      ),
    };
  }

  @override
  void dispose() {
    super.dispose();
    _refreshSubscription.cancel();
  }

  //Get current brightness with _brightness
  double _brightness = 1.0;

  double get brightness => _brightness;

  initPlatformState() async {
    _brightness = await ScreenProxy.brightness;
  }

  List<Widget> _buildCards(List<String> widgetSequence) {
    List<Widget> _widgets = [];
    List<Widget> _currentCardChildren = [];
    widgetSequence.forEach((element) {
      if (!getWidgetEnabledStatusFromSettings(element)) return;
      if (getWidgetStringFromSettings(element) == 'new_card') {
        if (_currentCardChildren.isEmpty) return;
        _widgets.add(Card(
          child: Column(
            children: _currentCardChildren,
          ),
        ));
        _currentCardChildren = [];
      } else if (getWidgetStringFromSettings(element) == 'custom_card') {
        _currentCardChildren.add(FeatureListItem(
          feature: CustomShortcutFeature(
              title: getCustomWidgetTitleFromSettings(element),
              link: getCustomWidgetLinkFromSettings(element)),
        ));
      } else {
        _currentCardChildren
            .add(widgetMap[getWidgetStringFromSettings(element)]);
      }
    });
    if (_currentCardChildren.isNotEmpty) {
      _widgets.add(Card(
        child: Column(
          children: _currentCardChildren,
        ),
      ));
    }
    return _widgets;
  }

  @override
  Widget build(BuildContext context) {
    List<String> widgetList =
        SettingsProvider.of(_preferences).dashboardWidgetsSequence;
    return RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          _rebuild();
          refreshSelf();
        },
        child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView(
              padding: EdgeInsets.all(4),
              children: _buildCards(widgetList),
            )));
  }
}
